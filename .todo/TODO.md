- `main`
  - Somehow tell which images to build through the commit message, instead of building all of them.
- `test`
  - metainfo generated in both, the build and the test tasks
    - versions of the tools
    - date of the build/test
    - commit sha (build only)
    - checksum
    - add this info to the tarball? if so, se comment about where to put it (below)
- `Pack artifacts`
  - [x] Pull all the `ghdl/pkg` images
    - [ ] Now `dockerfiles/run/*` are used. Somehow tell which to get.
  - [ ] Add metainfo to the packages/tarballs [[@tgingold 2017-02-14](https://github.com/tgingold/ghdl/issues/280#issuecomment-279595802)]
    - [ ] License
    - [ ] Readme
  - [ ] Add metainfo to `ghdl/ghdl` and `ghdl/pkg` images? If so, where (note that GHDL is preinstalled to `usr/local`)?
- `ext`
  - Add color bash prompt
  - Better build gtkwave from sources because #442

---

- [ ] Integration with play-with-docker (PWD)
  - [ ] eclipse/che demo in PWD: [eclipse/che#3595](https://github.com/eclipse/che/issues/3595#issuecomment-349852819)
  - [ ] Write dummy compose files and companion scripts to allow `play-with-docker.com/?stack=`
- [ ] Image tagging
  - [ ] Add release tag to images when a tagged commit is pushed
    - [ ] Push both, the tagged image and the `latest`
- [ ] Can docker images be removed programatically?
- [ ] ARM cross-compilation. Ready-to-use Rpi3 docker-based SD imgs available.

---

Check if nextpnr artifacts contain anything apart from the binary. It seems they don't.
