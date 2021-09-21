## zsh (grep, coreutils, findutils, ...)

<del>

- <https://packages.msys2.org/base/zsh>: find all of zsh's dependencies
  recursively, and download / extract them (i686 variant for 32-bit system).
- cp zsh.exe sh.exe (so /bin/sh is provided, and bash is not required)
- create an archive of `/etc` / `/usr`, if desired.

</del>

See <https://github.com/lxhillwind/msys2-bundle>.

## custom OS install

### using normal (official) OS
In a normal OS (like thin pc), extract custom OS archive to an empty drive (formatted as ntfs);
use `dism++` to write (fix) boot info (remember to select the correct drive!);
shutdown and attach the new drive as new host's boot device.

When booting new host, select another boot entry (since the first one is not actually available);
after desktop is setup, run `msconfig` via win+r, edit boot entry (delete the unused one).

### using WePE
prepare:
- download WePE executable, execute it to create an ISO.
- copy custom OS archive (`*.7z`) to another ISO (since ISO has filename limitation).

```sh
# man mkisofs (package: cdrtools)
mkisofs -o cd.iso cd_dir
```

Launch WePE ISO, extract data from archive inside another ISO to an empty drive (formatted as ntfs);
then use bootice to re-create MBR (select the correct NT version). (`dism++` may not work)

## thinpc 乱码 fix
控制面板-更该显示语言-管理: 非Unicode程序的语言选择简体中文.
