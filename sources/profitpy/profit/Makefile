targets = ../examples lib neuralnetdesigner strategydesigner workbench


.PHONY: all clean full $(targets)


all:
	@for dir in $(targets); do \
	  cd $$dir && $(MAKE) && cd - ;	done


clean:
	@rm -f -R *.pyc *.pyo
	@for dir in $(targets); do \
	  cd $$dir && $(MAKE) clean && cd - ; done


full:
	@for dir in $(targets); do \
	  cd $$dir && $(MAKE) full && cd - ; done
