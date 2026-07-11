{
  lib,
  buildNpmPackage,
  fetchFromGitHub,
  git,
  python3,
  udev,
  makeWrapper,
  nodejs_24,
  electron_41,
  node-gyp,
  gnugrep,
  gawk,
  xorg,
  procps,
  which,
}:

buildNpmPackage rec {
  pname = "tuxedo-control-center";
  version = "3.0.6";

  nodejs = nodejs_24;

  src = fetchFromGitHub {
    owner = "tuxedocomputers";
    repo = "tuxedo-control-center";
    rev = "v${version}";
    hash = "sha256-wb4dj0YjfO9h+1H91dwZL8XSt3oaMe+wmoka4kyMZg8=";
  };

  npmDepsHash = "sha256-O9lo1hrqktM8EXUEE6TYFC7AEI3140+CeqUmpwG8Kw4=";

  npmDepsFetcherVersion = 2;
  forceGitDeps = true;

  nativeBuildInputs = [ makeWrapper python3 git ];

  buildInputs = [ udev ];

  # Electron tries to download itself if this isn't set.
  ELECTRON_SKIP_BINARY_DOWNLOAD = 1;

  # Angular prompts for analytics, which fails the build.
  NG_CLI_ANALYTICS = "false";

  postPatch = ''
    substituteInPlace src/common/classes/TccPaths.ts \
      --replace "/etc/tcc" "/var/lib/tcc" \
      --replace "/opt/tuxedo-control-center/resources/dist/tuxedo-control-center/data/service/tccd" "$out/bin/tccd" \
      --replace "/opt/tuxedo-control-center/resources/dist/tuxedo-control-center/data/camera/cameractrls.py" \
        "$out/libexec/cameractrls.py" \
      --replace "/opt/tuxedo-control-center/resources/dist/tuxedo-control-center/data/camera/v4l2_kernel_names.json" \
        "$out/share/tcc/v4l2_kernel_names.json"

    substituteInPlace src/dist-data/tccd-sleep.service \
      --replace "/bin/bash -c " ""

    substituteInPlace src/dist-data/tccd.service \
      --replace "/opt/tuxedo-control-center/resources/dist/tuxedo-control-center/data/service/tccd" "$out/bin/tccd"

    substituteInPlace src/dist-data/tuxedo-control-center-tray.desktop \
      --replace "/opt/tuxedo-control-center/tuxedo-control-center" "tuxedo-control-center"

    substituteInPlace src/dist-data/tuxedo-control-center.desktop \
      --replace "/opt/tuxedo-control-center/tuxedo-control-center" "$out/bin/tuxedo-control-center" \
      --replace "/opt/tuxedo-control-center/resources/dist/tuxedo-control-center/data/dist-data/tuxedo-control-center_256.svg" \
        "$out/share/icons/hicolor/scalable/apps/tuxedo-control-center_256.svg"

    substituteInPlace src/udev/99-webcam.rules \
      --replace "/usr/bin/python3" "${python3}/bin/python3" \
      --replace "/opt/tuxedo-control-center/resources/dist/tuxedo-control-center/data/camera/cameractrls.py" "$out/libexec/cameractrls.py" \
      --replace "/etc/tcc/webcam" "/var/lib/tcc/webcam" \
      --replace "/opt/tuxedo-control-center/resources/dist/tuxedo-control-center/data/camera/v4l2_kernel_names.json" "$out/share/tcc/v4l2_kernel_names.json"
  '';

  buildPhase = ''
    runHook preBuild

    export PATH="./node_modules/.bin:$PATH"
    export NO_UPDATE_NOTIFIER=true

    # Build the electron app TypeScript
    npm run build-electron

    # Build native module.
    # We don't use npm run build-native-prod because it invokes node-gyp from
    # node_modules which tries to fetch the Node.js headers. We use the nixpkgs
    # node-gyp instead and point it to our nodejs headers.
    export npm_config_nodedir=${nodejs_24}
    ${node-gyp}/bin/node-gyp configure --release
    ${node-gyp}/bin/node-gyp rebuild --release

    # Build service app TypeScript and bundle with esbuild.
    # We don't use npm run build-service-prod because it calls `pkg` which packages
    # node binaries in a way unsuitable for nix. We run the steps manually and
    # wrap with node in postFixup instead.
    tsc -p ./src/service-app
    cp ./src/package.json ./dist/tuxedo-control-center/service-app/package.json
    mkdir -p ./dist/tuxedo-control-center/service-app/native-lib
    cp ./build/Release/TuxedoIOAPI.node ./dist/tuxedo-control-center/service-app/native-lib/
    esbuild ./dist/tuxedo-control-center/service-app/service-app/main.js \
      --tree-shaking=true \
      --bundle \
      --minify \
      --drop:debugger \
      --define:DEBUG=false \
      --platform=node \
      --loader:.node=copy \
      --asset-names=[name] \
      --outfile=./dist/tuxedo-control-center/service-app/service-app/esbuild.js

    # Build Angular frontend
    cp CHANGELOG.md ./src/ng-app/assets/
    ng build --configuration production --aot true --optimization true

    runHook postBuild
  '';

  dontNpmInstall = true;

  installPhase = ''
    runHook preInstall

    mkdir -p $out
    cp -R ./dist/tuxedo-control-center/* $out

    cp -r ./node_modules $out/node_modules

    mkdir -p $out/share/applications \
      $out/libexec \
      $out/share/tcc \
      $out/share/polkit-1/actions \
      $out/share/metainfo \
      $out/lib/systemd/system \
      $out/etc/dbus-1/system.d \
      $out/etc/udev/rules.d
    cp src/dist-data/tuxedo-control-center.desktop $out/share/applications/
    cp src/cameractrls/cameractrls.py $out/libexec/
    cp src/cameractrls/v4l2_kernel_names.json $out/share/tcc/
    cp src/dist-data/tuxedo-control-center-tray.desktop $out/share/tcc/
    cp src/dist-data/com.tuxedocomputers.tccd.policy $out/share/polkit-1/actions/
    cp src/dist-data/com.tuxedocomputers.tomte.policy $out/share/polkit-1/actions/
    cp src/dist-data/com.tuxedocomputers.tcc.metainfo.xml $out/share/metainfo/
    cp src/dist-data/tccd-sleep.service $out/lib/systemd/system/
    cp src/dist-data/tccd.service $out/lib/systemd/system/
    cp src/dist-data/com.tuxedocomputers.tccd.conf $out/etc/dbus-1/system.d/
    cp src/udev/99-webcam.rules $out/etc/udev/rules.d/

    mkdir -p $out/share/icons/hicolor/scalable/apps/
    cp src/dist-data/tuxedo-control-center_256.svg $out/share/icons/hicolor/scalable/apps/
    cp src/dist-data/tuxedo-control-center_256.png $out/share/icons/hicolor/scalable/apps/

    runHook postInstall
  '';

  postFixup = ''
    makeWrapper ${nodejs_24}/bin/node $out/bin/tccd \
      --add-flags "$out/service-app/service-app/esbuild.js" \
      --prefix PATH : "${
        lib.makeBinPath [
          gnugrep
          gawk
          xorg.xrandr
          procps
          which
        ]
      }" \
      --prefix NODE_PATH : "$out/node_modules"

    makeWrapper ${electron_41}/bin/electron $out/bin/tuxedo-control-center \
      --add-flags "$out/e-app/e-app/main.js" \
      --add-flags "--no-tccd-version-check" \
      --prefix PATH : "${lib.makeBinPath [ python3 ]}" \
      --prefix NODE_PATH : "$out/node_modules"
  '';

  meta = with lib; {
    description = "Fan and power management GUI for TUXEDO laptops";
    homepage = "https://github.com/tuxedocomputers/tuxedo-control-center/";
    license = licenses.gpl3Plus;
    mainProgram = "tuxedo-control-center";
    maintainers = [ maintainers.sund3RRR ];
    platforms = [ "x86_64-linux" ];
  };
}
