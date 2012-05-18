# git + webcam + imgur = lol

This is a branch of mroth's excellent [lolcommits](https://github.com/mroth/lolcommits) utility.

It originally takes a snapshot with your Mac's built-in iSight/FaceTime webcam (or any working webcam on Linux) every time you git commit code, and archives a lolcat style image with it. (Read more for [original version](https://github.com/mroth/lolcommits))

and now you can decide to upload the image to imgur.com and save it to your log message!

## Installation (read carefully)
You can't install it via gem, because you'll get the original lolcommits instead.

Grap a gem file at https://github.com/downloads/jangxyz/lolcommits/lolcommits-0.1.2.jx.1.gem and install this

    [sudo] gem install lolcommits-0.1.2.jx.1.gem 

This will do. Note if you were using the previous version, you need to uninstall it first.


## How To

You start with the same basic options. In your git root directory:

    lolcommits --enable (or -e)
    lolcommits --disable (or -d)

turns on and off the feature.

Now is the interesting part :)

    lolcommits --enable-imgur (or -E)

would turn the [imgur] mode. 
It uploads the image to imgur.com in every commit, and append the url to your commit message (use git log -1 to check).

Have fun! :)


