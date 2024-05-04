OBJ_NAME=controller-selector
CXX=g++
CXX_FLAGS=-Wall -O3
LIBS=-ludev -levdev -lSDL2 -lSDL2_ttf
OBJS=src/main.cpp

all: $(OBJ_NAME)

$(OBJ_NAME): $(OBJS)
	$(CXX) $(CXXFLAGS) $(OBJS) -o $(OBJ_NAME) $(LIBS)

clean:
	rm $(OBJ_NAME)
