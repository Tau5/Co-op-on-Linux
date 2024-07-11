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
	rm -rf AppDir
	rm $(OBJ_NAME).AppImage

install: $(OBJ_NAME)
	mkdir -p $(DESTDIR)/usr/share/co-op-on-linux
	mkdir -p $(DESTDIR)/usr/bin
	cp controller-selector $(DESTDIR)/usr/bin/co-ol-controller-selector
	cp -r assets $(DESTDIR)/usr/share/co-op-on-linux/

appimage: DESTDIR=AppDir
appimage: install
	NO_STRIP=true linuxdeploy --appdir=AppDir --desktop-file=controller-selector.desktop --icon-file=icon.png
	appimagetool AppDir $(OBJ_NAME).AppImage

