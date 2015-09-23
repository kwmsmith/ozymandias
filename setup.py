from distutils.core import setup
from Cython.Build import cythonize

setup(name="coriander",
      ext_modules=cythonize("vector.pyx"))
