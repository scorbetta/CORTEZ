PROJNAME=CORTEZ1
.PHONY: $(PROJNAME).pdf all clean

all: $(PROJNAME).pdf

# -pdf tells latexmk to generate PDF directly (instead of DVI).
# -pdflatex="" tells latexmk to call a specific backend with specific options.
# -use-make tells latexmk to call make for generating missing files.
# -interactive=nonstopmode keeps the pdflatex backend from stopping at a
# missing file reference and interactively asking you for an alternative.
$(PROJNAME).pdf: $(PROJNAME).tex
	latexmk -pdf -pdflatex="pdflatex -interactive=nonstopmode" -use-make $<

clean:
	latexmk -C
	rm -f $(PROJNAME).bbl
