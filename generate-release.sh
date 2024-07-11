mkdir release
pushd controller-selector
make appimage
mkdir -p ../release/controller-selector
cp controller-selector.AppImage ../release/controller-selector/controller-selector
popd

cp Co-Op-On-Linux.sh release/
cp create-new-profile.sh release/
cp install-steamos.sh release/
cp get-devices.py release/
cp README.md release/

chmod a+x release/*.sh
chmod a+x release/controller-selector/controller-selector

tar -czvf release.tar.gz release
rm -r release