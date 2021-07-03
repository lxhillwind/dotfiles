## vim
[\_vimrc](_vimrc) should be put in vim/ directory (same level with vim82).

```console
vim
vim/vim82
vim/_vimrc
vim/home/
vim/home/.config/env.sh
vim/home/vimfiles/
vim/extern/
vim/extern/MinGit/
vim/extern/MinGit/cmd/git.exe
vim/extern/MinGit-2.10.0/
vim/extern/MinGit-2.10.0/cmd/git.exe
vim/extern/bin/
vim/extern/bin/busybox.exe
vim/extern/bin/less.exe
```

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
