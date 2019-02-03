# Use Python REPL in Julia

![example](Python.png)
## Installation
Make sure PyCall.jl work well before installation, then
`(v1.0) pkg> add https://github.com/229668880/Python.jl.git`
Python.jl can work with Julia 1.0 and Python 3 on Windows.

## Usage

Python.jl is only based on PyCall.jl, and helps to use Python native codes freely (include plotting with matplotlib) in Julia's REPL or by providing a Python REPL mode for running code as you do in Python's command-line interface. Python.jl will work properly if PyCall.jl works well with Python. It doesn't need any more installation and configuration.

Run `using Python` and start Python at backend, then:

1. __Julia REPL__: use macro `@py python_codes` to run Python codes, or `@py variable_name` to show the value of a variable in Python. Since PyCall.jl has been imported, you can embed `py"a"` in any codes to use the value of `a` which is created in Python by `@py a=100`, e.g. `py"a"*1000` in Julia REPL.

2. __Python REPL__: type `Ctrl+)` in empty `julia>` to enter Python REPL, and input any Python codes as you do in in Python command-line interface. You can switch back to Julia REPL by `backspace`.

3. __Transfer data between two REPL__: In Julia REPL, use `a=py[:b]` to copy `b` in Python to `a` in Julia, and `py[:c]=d` to copy `d` in Julia to `c` in Python. Operations like `100*py[:b]` are allowed. In Python REPL, `$d+100` causes the same effect.

4. __Plotting__: After `using Python` initializes, Python codes `from matplotlib.pylab import *` and `import matplotlib.pyplot as plt` have been executed in Python backend,so you can plot with typing`plot(randn(100))`. Plotting functionalities are only based on PyCall.jl, independent of PyPlot.jl, and  let you plot freely as in IPython. Python.jl works well with Qt5, and maybe need `show()` function to display plotting window for unknown reason.

**Note:**
If plotting doesn't work, try to `pip3 install pyqt5` and make sure Qt5 is your plotting backend in Python. If there is any unpredicted errors, try `using PyCall` before your operation.

## Requirements

### Julia

* PyCall.jl

### Python

* Any version of Python that makes PyCall.jl work properly.


