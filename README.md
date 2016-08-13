
cocos2dx-lite
=========

It bases on [cocos2d-x](https://github.com/cocos2d/cocos2d-x) v3 branch, but remove 3D and other features.
It works on iOS, Android, OS X and Windows.

The major change:

- Only support iOS,OS X,Android and Windows.
- Remove 3D features
- Remove support for JS script
- Remove deprecated classes and functions
- Remove Camera
- Remove Physics integration
- Remove C++ implementations of Component
- Remove C++ implementations of CocoStudio parser
- Remove C++ implementations of CocosBuilder parser
- Remove AssetsManager, AssetsManagerEX
- Remove support for WebP,S3TC,ATITC
- Remove FastTileMap, TileMap
- Remove *Menu*
- Remove `Focus` event
- Improve module compile `cocos/base/ccConfigUser.h`
- Improve curl library, only support `socket` and `http` protocol
- Add [CC_MINI_2D / CC_USE_FREETYPE / CC_ONLY_PNG](https://github.com/c0i/cocos2dx-lite/blob/master/cocos/base/ccConfigUser.h)
- Add CC_USE_SPINE
- Add CC_USE_AUDIO_ENGINE
- Add CC_USE_NETWORK

## How to start

1. setup env

    ```
    $ # clone repo
    $ git clone https://github.com/c0i/cocos2dx-lite.git
    $ cd cocos2dx-lite
    $ ./setup.py
    $ source ~/.bash_profile
    ```

2. try with player project

    ```
    $ open player/proj.ios_mac/player.xcodeproj/
    $ or
    $ cocos run -p mac # ios, android
    ```

## Contributing to the Project

Cocos2dx-lite is licensed under the [MIT License](https://opensource.org/licenses/MIT). We welcome participation!

## Others

There are lots of better cocos2d-x forks:

- https://github.com/stubma/cocos2dx-classical
- https://github.com/IppClub/Dorothy
