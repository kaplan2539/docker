from pathlib import Path

from build import build_image

#images = [
#    "cache:gtkwave",
#    "cache:formal",
#
#    "synth:icestorm",
#    "synth:trellis",
#    "synth:prog",
#    "synth:nextpnr-ice40",
#    "synth:nextpnr-ecp5",
#    "synth:nextpnr",
#
#    "synth:yosys",
#    "cache:yosys-gnat",
#
#    "synth:latest",
#    "synth:beta",
#    "synth:formal",
#
#    "synth:symbiyosys",
#    "build:buster-mcode",
#    "run:buster-mcode",
#]


#ext
#  synth:
#      run: ./run.sh -e synth
#    - name: Deploy to hub.docker.com
#      run: ./run.sh synth
#
#      printf "${ANSI_MAGENTA}[Clone] tgingold/ghdlsynth-beta${ANSI_NOCOLOR}\n"
#      mkdir -p ghdlsynth
#      cd ghdlsynth
#      curl -fsSL https://codeload.github.com/tgingold/ghdlsynth-beta/tar.gz/master | tar xzf - --strip-components=1
#      printf "${ANSI_MAGENTA}[Run] ./ci.sh${ANSI_NOCOLOR}\n"
#      ./ci.sh
#      cd ..
#
#      DREPO=synth DTAG="formal" DFILE=synth_formal build_img
#
#  ls:
#        task: [ debian, ubuntu ]
#      run: ./run.sh -l $TASK
#      env:
#        TASK: ${{ matrix.task }}
#    - name: Deploy to hub.docker.com
#      run: ./run.sh ext
#
#  distro="$1"
#  llvm_ver="7"
#  if [ "x$distro" = "xubuntu" ]; then
#    llvm_ver="6.0"
#  fi
#  TAG="ls-$distro" DREPO="ext" DTAG="ls-$distro" DFILE=ls_debian build_img --build-arg "DISTRO=$distro" --build-arg LLVM_VER=$llvm_ver


def task(name, args, dry_run=False):
    sw = {
        "gtkwave": ("cache", "gtkwave"),

        "pnr": map( lambda tag: ("synth", tag),
        ["icestorm", "trellis", "prog", "nextpnr-ice40", "nextpnr-ecp5", "nextpnr"]
        ),

        "yosys": [
            ("synth", "yosys"),
            ("cache", "yosys-gnat")
        ],

        "formal": ("cache", "formal"),

        "symbiyosys": ("synth", "symbiyosys"),

        "vunit": map( lambda backend: map( lambda tag: ("vunit", tag), [backend, "%s-master" % backend]
        ), ["mcode", "llvm", "gcc"]
        ),

        "gui": map( lambda tag: ("ext", tag), ["ls-vunit", "latest", "broadway"]),
    }
    if name not in sw:
        raise Exception("invalid task name '%s'" % name)
    print("TASK: %s %s" % (name, ' '.join(args)))

    def extract(t):
        if isinstance(t, map):
            lst = []
            for tt in t:
                lst += extract(tt)
            return lst
        if isinstance(t, list):
            return t
        return [t]

    for job in extract(sw[name]):
        print(' ', *job)
        build(*job, dry_run=dry_run)


def build(repo, tag, dry_run=False):
    def b_c(tag):
        # expected values for tag are: gtkwave, yosys-gnat or formal
        dfile = tag
        if tag == "yosys-gnat":
            dfile = "yosys"
        return ("cache", tag, "cache_%s" % dfile)

    def b_s(tag):
        if tag == "yosys":
            return ("synth", tag, "cache_yosys", {
                "target": "yosys"
            })
        if tag == "symbiyosys":
            return ("synth", tag, "synth_formal", {
                "args": [
                    'IMAGE=ghdl/synth:yosys'
                ]
            })
        # other expected values for tag are: icestorm trellis prog nextpnr-ice40 nextpnr-ecp5 nextpnr
        return ("synth", tag, "cache_pnr", {
            "target": tag
        })

    def b_b(tag):
        return ("build", tag, None)

    def b_r(tag):
        return ("run", tag, None)

    def b_v(tag):
        cmp = tag.split('-')
        backend = cmp[0]

        sw = {
            "mcode": "",
            "llvm": "-7",
            "gcc": "-8.3.0"
        }
        args = ['TAG=buster-%s%s' % (backend, sw[backend])]
        if backend == "gcc":
            args += ['PY_PACKAGES=gcovr']

        return ("vunit", tag, "vunit", {
            "target": cmp[1] if len(cmp)>1 else "stable",
            "args": args
        })

    def b_e(tag):
        if tag == "broadway":
            return ("ext", "broadway", "gui", {
                "target": "broadway",
                "context": str(Path(__file__).parent.parent)
            })
        # other expected values for tag are: ls-vunit latest
        return ("ext", tag, "gui", {
            "target": tag
        })

    sw = {
        "cache": b_c,
        "synth": b_s,
        "build": b_b,
        "run": b_r,
        "vunit": b_v,
        "ext": b_e,
    }
    if repo not in sw:
        raise Exception("invalid repo name '%s'" % repo)
    print('BUILD: %s %s' % (repo, tag))
    build_image(*sw[repo](tag), dry_run=dry_run)
