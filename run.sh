#!/usr/bin/env sh

set -e

. $(dirname $0)/utils.sh

cd $(dirname $0)/dockerfiles

export DOCKER_BUILDKIT=1

#SKIP_BUILD=true
#SKIP_DEPLOY=true

#--

case "$TRAVIS_COMMIT_MESSAGE" in
  *'[skip]'*)
    SKIP_BUILD=true
  ;;
esac
echo "SKIP_BUILD: $SKIP_BUILD"

#--

build_img () {
  gstart "[DOCKER build] $DREPO : ${DTAG}"
  DCTX="-"
  case "$1" in
    "--ctx"*)
    DCTX="-f- $(echo $1 | sed 's/--ctx=//g')"
    shift
    ;;
  esac
  printf "· ${ANSI_CYAN}File: ${ANSI_NOCOLOR}"
  echo "$DFILE"
  printf "· ${ANSI_CYAN}Ctx:  ${ANSI_NOCOLOR}"
  echo "$DCTX"
  printf "· ${ANSI_CYAN}Args: ${ANSI_NOCOLOR}"
  echo "$@"
  if [ "x$SKIP_BUILD" = "xtrue" ]; then
    printf "${ANSI_YELLOW}SKIP_BUILD...$ANSI_NOCOLOR\n"
  else
    docker build -t "ghdl/${DREPO}:$DTAG" "$@" $DCTX < $DFILE
  fi
  gend
}

build_debian_images () {
  for tag in mcode llvm gcc; do
    i="${ITAG}-$tag"
    if [ "x$tag" = "xllvm" ]; then i="$i-$LLVM_VER"; fi
    TAG="$d-$i" \
    DREPO="$d" \
    DTAG="$i" \
    DFILE="${d}_debian" \
    build_img \
    --target="$tag" \
    "$@"
  done
}

#--

create () {
  TASK="$1"
  VERSION="$2"
  case $TASK in
    ls)
      case "$VERSION" in
        debian)
          BASE_IMAGE="python:3-slim-buster"
          LLVM_VER="7"
          GNAT_VER="7"
          APT_PY=""
        ;;
        ubuntu)
          BASE_IMAGE="ubuntu:bionic"
          LLVM_VER="6.0"
          GNAT_VER="7"
          APT_PY="python3 python3-pip"
        ;;
      esac
      for img in build run; do
        TAG="ghdl/$img.ls-$VERSION" \
        DREPO="$img" \
        DTAG="ls-$VERSION" \
        DFILE=ls_debian_base \
        build_img \
        --target="$img" \
        --build-arg IMAGE="$BASE_IMAGE" \
        --build-arg LLVM_VER="$LLVM_VER" \
        --build-arg GNAT_VER="$GNAT_VER" \
        --build-arg APT_PY="$APT_PY"
      done
    ;;

    *)
      for d in build run; do
          case $TASK in

            "debian")
              case $VERSION in
                *stretch*)
                  LLVM_VER="4.0"
                  GNAT_VER="6"
                ;;
                *buster*)
                  LLVM_VER="7"
                  GNAT_VER="8"
                ;;
                *sid*)
                  LLVM_VER="8"
                  GNAT_VER="8"
                ;;
              esac
              ITAG="$VERSION"
              build_debian_images \
                --build-arg IMAGE="$TASK:$VERSION-slim" \
                --build-arg LLVM_VER="$LLVM_VER" \
                --build-arg GNAT_VER="$GNAT_VER"
            ;;

            "ubuntu")
              case $VERSION in
                14) #trusty
                  LLVM_VER="3.8"
                  GNAT_VER="4.6"
                ;;
                16) #xenial
                  LLVM_VER="3.9"
                  GNAT_VER="4.9"
                ;;
                18) #bionic
                  LLVM_VER="5.0"
                  GNAT_VER="7"
                ;;
              esac
              ITAG="ubuntu$VERSION"
              build_debian_images \
                --build-arg IMAGE="$TASK:$VERSION.04" \
                --build-arg LLVM_VER="$LLVM_VER" \
                --build-arg GNAT_VER="$GNAT_VER"
            ;;

            "fedora")
              for tgt in  mcode llvm gcc; do
                i="fedora${VERSION}-$tgt"
                TAG="$d-$i" DREPO="$d" DTAG="$i" DFILE="${d}_fedora" build_img --target="$tgt" --build-arg IMAGE="fedora:${VERSION}"
              done
            ;;
          esac
      done
    ;;
  esac
}

#--

deploy () {
  case $1 in
    "")
      FILTER="/ghdl /pkg";;
    "base")
      FILTER="/build /run";;
    "ext")
      FILTER="/ext";;
    "synth")
      FILTER="/synth";;
    "vunit")
      FILTER="/vunit";;
    "pkg")
      FILTER="/pkg:all";;
    *)
      FILTER="/";;
  esac

  echo "$DOCKER_PASS" | docker login -u "$DOCKER_USER" --password-stdin

  echo "IMAGES: $FILTER"
  docker images

  for key in $FILTER; do
    for tag in `echo $(docker images "ghdl$key*" | awk -F ' ' '{print $1 ":" $2}') | cut -d ' ' -f2-`; do
      if [ "$tag" = "REPOSITORY:TAG" ]; then break; fi
      i="`echo $tag | grep -oP 'ghdl/\K.*' | sed 's#:#-#g'`"
      gstart "[DOCKER push] ${tag}" "$ANSI_YELLOW"
      if [ "x$SKIP_DEPLOY" = "xtrue" ]; then
        printf "${ANSI_YELLOW}SKIP_DEPLOY...$ANSI_NOCOLOR\n"
      else
        docker push $tag
      fi
      gend
    done
  done

  docker logout
}

#--

build () {
  CONFIG_OPTS="--default-pic " ./dist/ci-run.sh -c "$@"

  if [ "$GITHUB_OS" != "macOS" ] && [ -f testsuite/test_ok ]; then
    IMAGE_TAG="$(docker images "ghdl/ghdl:*" | head -n2 | tail -n1 | awk -F ' ' '{print $2}')"
    if echo $IMAGE_TAG | grep '\-synth'; then
      BASE_TAG="$IMAGE_TAG"
      IMAGE_TAG="$(echo $BASE_TAG | sed 's/-synth//g')"
      docker tag ghdl/ghdl:$BASE_TAG ghdl/ghdl:$IMAGE_TAG
      docker rmi ghdl/ghdl:$BASE_TAG
    fi
    gstart "[CI] Docker build ghdl/pkg:${IMAGE_TAG}"
    docker build -t "ghdl/pkg:$IMAGE_TAG" . -f-<<EOF
FROM scratch
ADD `ls | grep -v '\.src\.' | grep '^ghdl.*\.tgz'` ./
EOF
    gend
  fi
}

#--

case "$1" in
  -c)
    shift
    create "$@"
  ;;
  -s)
    printf "${ANSI_MAGENTA}[Clone] tgingold/ghdlsynth-beta${ANSI_NOCOLOR}\n"
    mkdir -p ghdlsynth
    cd ghdlsynth
    curl -fsSL https://codeload.github.com/tgingold/ghdlsynth-beta/tar.gz/master | tar xzf - --strip-components=1
    printf "${ANSI_MAGENTA}[Run] ./ci.sh${ANSI_NOCOLOR}\n"
    ./ci.sh
    cd ..
    DREPO=synth DTAG="formal" DFILE=synth_formal build_img
  ;;
  -b)
    shift
    cd ../ghdl
    build "$@"
  ;;
  -l)
    shift
    distro="$1"
    llvm_ver="7"
    if [ "x$distro" = "xubuntu" ]; then
      llvm_ver="6.0"
    fi
    TAG="ls-$distro" DREPO="ext" DTAG="ls-$distro" DFILE=ls_debian build_img --build-arg "DISTRO=$distro" --build-arg LLVM_VER=$llvm_ver
  ;;
  *)
    deploy $@
esac
