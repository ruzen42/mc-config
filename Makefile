HC=ghc
SRC=src/Main.hs
HF=-O2
OUT=mc-config

all:
	$(HC) $(SRC) $(HF) -o $(OUT)

clean:
	rm "src/*.o" "src/*.hi" $(OUT)