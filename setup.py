from distutils.core import setup
from Cython.Build import cythonize

setup(name="ozymandias",
      version='0.0.1',
      description='Functional persistent data structures for Python.',
      author='Kurt W. Smith',
      author_email='kwmsmith@gmail.com',
      url='https://github.com/kwmsmith/ozymandias',
      ext_modules=cythonize("*.pyx"),
      classifiers=[
          "Development Status :: 2 - Pre-Alpha",
          "Intended Audience :: Developers",
          "License :: OSI Approved :: BSD License",
          "Operating System :: MacOS :: MacOS X",
          "Operating System :: POSIX",
          "Operating System :: Unix",
          "Operating System :: Microsoft :: Windows",
          "Programming Language :: Python :: 2.7",
          "Programming Language :: Cython",
          "Topic :: Software Development :: Libraries :: Python Modules",
          ],)
