# 386root

This is basically the spiritual sucessor to Thirty-Two-Bit, my little dinky Linux distro based off of gray386linux, for, well, i386 computers. This is kinda like that but a zillion times better.

The base for this is Buildroot 2016.02, which was the last to support the Intel 386. I had to do a little work for it to work on modern computers, but it does!

# Building

Make sure you have all the normal dependancies for Buildroot installed, and then you should be pretty good to go. The only other dependancy is probably `mtools` so you have `mcopy`.

```sh
make 386root_defconfig		# To copy the configuration files for 386root
make				# Builds the distro (use -j flags!)
sudo board/386root/make_disk.sh	# Makes the disk image (needs root)
```
