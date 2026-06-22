PROJECT := NewFileCreator/NewFileCreator.xcodeproj
SCHEME := NewFileCreator
CONFIGURATION := Release
DERIVED_DATA := build/DerivedData
APP := build/NewFileCreator.app

.PHONY: build install-local icons demo release clean

build:
	./scripts/build.sh

install-local:
	./scripts/install-local.sh

icons:
	./scripts/generate-app-icons.sh

demo:
	./scripts/generate-demo-video.sh

release:
	./scripts/package-release.sh

clean:
	rm -rf build
