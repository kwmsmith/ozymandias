CSOURCES = vector.c map.c set.c
SOS = vector.so map.so set.so

test: $(SOS)
	py.test
.PHONY: test

%.so: %.pyx
	python setup.py build_ext -if

clean:
	-rm -rf build __pycache__ $(SOS) $(CSOURCES)
.PHONY: clean
