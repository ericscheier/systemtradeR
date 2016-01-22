pyrcc = pyrcc4
pyrccopt = -o
images := `find ./images -name "*.png"|sort|cut -b 3-`
rcsrc = profit.qrc
rcout = profit_rc.py

pyuic = pyuic4
pyuicopt = -x -o
objects := $(addsuffix .py, $(basename $(wildcard *.ui)))



.PHONY: all clean full $(rcout)

all: $(objects)


clean:
	@rm -f $(objects) *.pyc *.pyo


#full: all $(rcout)
full: all


$(objects): %.py: %.ui
	$(pyuic) $(pyuicopt) $@ $< 


$(rcout):
	@rm -f $(rcsrc)
	@echo '<!DOCTYPE RCC><RCC version="1.0">' >> $(rcsrc)
	@echo '<qresource>' >> $(rcsrc)
	@for file in $(wordlist 1,$(words $(images)),$(images)); \
		do echo "<file>$${file}</file>" >> $(rcsrc); done
	@echo '</qresource>' >> $(rcsrc)
	@echo '</RCC>' >> $(rcsrc)
	$(pyrcc) $(pyrccopt) $@ $(rcsrc)

