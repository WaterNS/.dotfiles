# POSIX OS bootstrap (OSX/Linux):
1. Install git (if needed): https://git-scm.com/download/

2. Init dotfiles
```
git clone https://github.com/WaterNS/.dotfiles.git ~/.dotfiles && \
  cd .dotfiles && ./init_posix.sh
```

3. Add SSH pubkey to github account:
```
pubkey WaterNS
```

4. Update local repo with SSH remote:
```
cd ~/.dotfiles && git remote set-url origin git@github.com:WaterNS/.dotfiles.git
```