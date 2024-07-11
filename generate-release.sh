mkdir release
pushd controller-selector
make appimage
cp controller-selector.AppImage ../release/controller-selector
popd

cp Co-Op-On-Linux.sh release/
cp create-new-profile.sh release/
cp install-steamos.sh release/
cp get-devices.py release/

chmod a+x release/*.sh
chmod a+x release/controller-selector
chmod a+x release/get-devices.py

tar -czvf release.tar.gz release
rm -r release