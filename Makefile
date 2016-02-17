CSOURCES = ozymandias/vector.c ozymandias/map.c ozymandias/set.c
SOS = ozymandias/vector.so ozymandias/map.so ozymandias/set.so

test: $(SOS)
	py.test
.PHONY: test

all: $(SOS)
.PHONY: all

%.so: %.pyx
	python setup.py build_ext -if

clean:
	-rm -rf build __pycache__ $(SOS) $(CSOURCES)
.PHONY: clean
