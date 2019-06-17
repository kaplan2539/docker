#! /bin/sh

set -e

cd $(dirname $0)/..

. ./travis/utils.sh

#--

create () {
  files="stretch buster"
  if [ "$DISTRO" != "debian" ]; then
    cd ./dockerfiles/build
    files="`ls ${DISTRO}*`"
    cd -
  fi
  for d in build run; do
      ddir="./dockerfiles/$d"
      for f in $files; do
          for tag in `grep -oP "FROM.*AS \K.*" ${ddir}/$f`; do
              i="${f}-$tag"
              travis_start "$i" "${ANSI_BLUE}[DOCKER build] ${d} : ${f} - ${tag}$ANSI_NOCOLOR"
              docker build -t "ghdl/${d}:$i" --target "$tag" - < "${ddir}/$f"
              travis_finish "$i"
          done
      done
  done
}

#--

extended() {
  ddir="./dockerfiles/ext"
  for f in `ls $ddir`; do
      for tag in `grep -oP "FROM.*AS do-\K.*" ${ddir}/$f`; do
          travis_start "$tag" "$ANSI_BLUE[DOCKER build] ext : ${tag}$ANSI_NOCOLOR"
          docker build -t ghdl/ext:${tag} --target do-$tag . -f ${ddir}/$f
          travis_finish "$tag"
      done
  done
  #docker build -t ghdl/ext:broadway --target do-broadway . -f ./dist/linux/docker/ext/vunit
}

#--

language_server() {
  distro="$1"
  for img in build run; do
      tag="ghdl/$img:ls-$distro"
      travis_start "$tag" "$ANSI_BLUE[DOCKER build] ext : ${tag}$ANSI_NOCOLOR"
      docker build -t $tag . -f ./dockerfiles/ext/ls_${distro}_base --target=$img
      travis_finish "$tag"
  done
  llvm_ver="4.0"
  if [ "x$distro" = "xubuntu" ]; then
    llvm_ver="6.0"
  fi
  tag="ghdl/ext:ls-$distro"
  travis_start "$tag" "$ANSI_BLUE[DOCKER build] ext : ${tag}$ANSI_NOCOLOR"
  docker build -t $tag . -f ./dockerfiles/ext/ls_debian --build-arg DISTRO="$distro" --build-arg LLVM_VER="$llvm_ver"
  travis_finish "$tag"
}

#--

deploy () {
  case $1 in
    "")    FILTER="/";;
    "ext") FILTER="/ext";;
    "pkg") FILTER="/pkg:all";;
    *)     FILTER="/ghdl /pkg";;
  esac

  . ./travis/docker_login.sh

  for key in $FILTER; do
    for tag in `echo $(docker images "ghdl$key*" | awk -F ' ' '{print $1 ":" $2}') | cut -d ' ' -f2-`; do
        if [ "$tag" = "REPOSITORY:TAG" ]; then break; fi
        i="`echo $tag | grep -oP 'ghdl/\K.*'`"
        travis_start "$i" "$ANSI_YELLOW[DOCKER push] ${tag}$ANSI_NOCOLOR"
        docker push $tag
        travis_finish "$i"
    done
  done

  docker logout
}

#--

build_img_pkg() {
    IMAGE_TAG=`echo $IMAGE | sed -e 's/+/-/g'`
    travis_start "build_scratch" "$ANSI_BLUE[DOCKER build] ghdl/pkg:${IMAGE_TAG}$ANSI_NOCOLOR"
    docker build -t ghdl/pkg:$IMAGE_TAG . -f-<<EOF
FROM scratch
COPY `ls | grep '^ghdl.*\.tgz'` ./
COPY BUILD_TOOLS ./
EOF
    travis_finish "build_scratch"
}

build () {
  cd ghdl
  CONFIG_OPTS="--default-pic " ./dist/travis/travis-ci.sh

  if [ "$TRAVIS_OS_NAME" != "osx" ]; then
    if [ -f test_ok ]; then
      build_img_pkg
    fi
  fi
  cd ..
}

#--

case "$1" in
  -b) build    ;;
  -c) create   ;;
  -e) extended ;;
  -l) language_server "$2";;
  *)
    deploy $@
esac
