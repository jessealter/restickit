# restickit.pl
## Simple Restic backups in a Perl script

I needed a backup script for [Restic](https://restic.net) for my server. My criteria was:

* **Simple:** When it comes to my backups, I need to understand how something works before I can trust it.

* **Written in Perl:** Many Restic scripts already exist, but not so many in Perl. I write a lot of Perl at work, and at this point I'm more at home writing Perl than Bash. 

* **No extra dependencies:** I am avoiding modules that are not part of the standard Perl distribution. Restic ships as a single Go binary that doesn't need any dependencies, so I wanted my script to run anywhere that has Perl.

Rather than start from scratch, I found Joe Block's excellent [restic-driver script](https://unixorn.github.io/post/restic-backups-on-truenas/) on his blog. I really liked the way the script was organized, so I ported it from Bash before putting my own spin on it. Additional spins will come as my needs change. :)

I also considered using Michael Lynch's [resticpy](https://mtlynch.github.io/resticpy/) Python wrapper for Restic, which seems like it would also be a really comfortable option.

## Usage
```bash
restic-driver.pl restic-settings.conf
```

If you want to read the settings file into your shell's environment, source it through the readenv.sh script:

```bash
source readenv.sh restic-settings.conf
```
