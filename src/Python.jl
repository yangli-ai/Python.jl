module Python

using PyCall
using REPL
import REPL:LineEdit

export pymain, @pyput, @pyget, @py, py_choosegui

const pymain=pyimport("__main__")

function __init__()
    pymain[:juliatemp]="import matplotlib.pyplot as plt\nfrom matplotlib.pylab import *\nplt.ion()\n"
    py"exec(juliatemp)"
    pymain[:juliagui]="qt5"
    pygui_start(:qt5)
	active_repl=Base.active_repl;
    main_mode=active_repl.interface.modes[1]
    main_mode.keymap_dict = LineEdit.keymap_merge(main_mode.keymap_dict,pykeys)
	nothing
end

function py_choosegui(gui=:qt5)
    try
       pygui_start(gui)
	catch
	   print("please install qt5 for python: pip3 install pyqt5\n")
    end
end

macro pyput(args...) 
    if !@isdefined pymain
       global pymain=pyimport("__main__")	
	end
    for a in args                        
         eval(Meta.parse("pymain[:$a]=$a")) 
    end                              
end    
 
macro pyget(args...)
    if !@isdefined pymain
       global pymain=pyimport("__main__")	
	end
    for a in args                        
         eval(Meta.parse("$a=pymain[:$a]")) 
    end    
end

macro py(args...)
    juliatemp=join([string(i) for i in args]," ")
	try
	  if occursin(r"^\w*$",juliatemp)
         pymain[:juliatemp]=string("print(",juliatemp,")")
	  else
         pymain[:juliatemp]=juliatemp
	  end
	  py"exec(juliatemp)"
	catch err
	  print(err.val)
	end
end

function parse_status(script::String)
    status = :ok
    status
end

# See: https://github.com/JuliaInterop/RCall.jl/blob/master/src/RPrompt.jl
function bracketed_paste_callback(s, o...)
    input = LineEdit.bracketed_paste(s)
    sbuffer = LineEdit.buffer(s)
    curspos = position(sbuffer)
    seek(sbuffer, 0)
    shouldeval = (bytesavailable(sbuffer) == curspos && search(sbuffer, UInt8('\n')) == 0)
    seek(sbuffer, curspos)
    if curspos == 0
        input = lstrip(input)
    end

    if !shouldeval
        LineEdit.edit_insert(s, input)
        return
    end

    LineEdit.edit_insert(sbuffer, input)
    input = String(take!(sbuffer))

    oldpos = start(input)
    nextpos = 0
    while !done(input, oldpos)
        nextpos = search(input, '\n', nextpos+1)
        if nextpos == 0
            nextpos = endof(input)
        end
        block = input[oldpos:nextpos]
        status = parse_status(block)

        if status == :error  || (status == :incomplete && done(input, nextpos+1)) ||
                (done(input, nextpos+1) && !endswith(input, '\n'))
            LineEdit.replace_line(s, input[oldpos:end])
            LineEdit.refresh_line(s)
            break
        elseif status == :incomplete && !done(input, nextpos+1)
            continue
        end

        if !isempty(strip(block))
            LineEdit.replace_line(s, strip(block))
            LineEdit.commit_line(s)
            terminal = LineEdit.terminal(s)
            REPL.raw!(terminal, false) && LineEdit.disable_bracketed_paste(terminal)
            LineEdit.mode(s).on_done(s, LineEdit.buffer(s), true)
            REPL.raw!(terminal, true) && LineEdit.enable_bracketed_paste(terminal)
        end
        oldpos = nextpos + 1
    end
    LineEdit.refresh_line(s)
end

mutable struct PyCompletionProvider <: LineEdit.CompletionProvider
    py::REPL.LineEditREPL
end

function create_py_repl(repl,main)
    py_mode = LineEdit.Prompt("Python> ";
        prompt_prefix=Base.text_colors[:blue],
		prompt_suffix=main.prompt_suffix,
        sticky=true)
    hp = main.hist
    hp.mode_mapping[:py] = py_mode
    py_mode.hist = hp
    py_mode.complete = PyCompletionProvider(repl)
    py_mode.on_enter = (s) -> begin
        status = parse_status(String(take!(copy(LineEdit.buffer(s)))))
        status == :ok || status == :error
    end
    py_mode.on_done = (s, buf, ok) -> begin
        if !ok
            return REPL.transition(s, :abort)
        end
        script = String(take!(buf))
        if !isempty(strip(script))
		    REPL.reset(repl)
			try
			    if lastindex(script)>=6 && script[1:6]=="@jlget"
				       args=strip(script[7:end])
					   for a in split(args," ",keepempty=false)
					      a=strip(a)
                          eval(Meta.parse("pymain[:$a]=$a")) 
                       end
                       #@pyput strip(script[7:end])
                elseif lastindex(script)>=6 && script[1:6]=="@jlput"
				       args=strip(script[7:end])
                       for a in split(args," ",keepempty=false)
                          a=strip(a)
                          eval(Meta.parse("$a=pymain[:$a]")) 
                       end
                       #@pyget strip(script[7:end])
                elseif occursin(r"^\w*$",script)
				       pymain[:juliatemp]=string("print(",script,")")
					   py"exec(juliatemp)"
                else
				       pymain[:juliatemp]=script
                       py"exec(juliatemp)"
			    end
			catch err
                print(err.val)
			end
        end
		REPL.prepare_next(repl)
        REPL.reset_state(s)
        s.current_mode.sticky || REPL.transition(s,main)
    end

    bracketed_paste_mode_keymap = Dict{Any,Any}(
        "\e[200~" => bracketed_paste_callback
    )
		
    search_prompt, skeymap = LineEdit.setup_search_keymap(hp)
    prefix_prompt, prefix_keymap = LineEdit.setup_prefix_keymap(hp, py_mode)
	
	mk = REPL.mode_keymap(main)
    delete!(mk, "^C")
	
    b = Dict{Any,Any}[
        bracketed_paste_mode_keymap,
        skeymap, mk, prefix_keymap, LineEdit.history_keymap,
        LineEdit.default_keymap, LineEdit.escape_defaults
    ]
    py_mode.keymap_dict = LineEdit.keymap(b)
	
    py_mode
end

const pykeys = Dict{Any,Any}(
    ")"=> (s,o...)->(
	     if isempty(s) || position(LineEdit.buffer(s)) == 0
		    repl = Base.active_repl
			mirepl = isdefined(repl,:mi) ? repl.mi : repl
			main_mode = mirepl.interface.modes[1]
            py_mode = create_py_repl(repl,main_mode)
            buf = copy(LineEdit.buffer(s))
            LineEdit.transition(s,py_mode) do
               LineEdit.state(s,py_mode).input_buffer = buf
            end
         else
            LineEdit.edit_insert(s, ')')
         end
		  ),
)

function customize_keys(repl)
    repl.interface = REPL.setup_interface(repl; extra_repl_keymap = pykeys)
end

#atreplinit(customize_keys)  if you run codes in startup.jl

end # module