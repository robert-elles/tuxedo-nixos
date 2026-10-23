# Based on nixpkgs' pkgs/os-specific/linux/tuxedo-drivers. Kept here because
# nixpkgs still ships 4.20.1, which does not build against kernel >= 7.3
# (`struct acpi_driver` was removed; 4.25.0 ports clevo_acpi to
# platform_driver). Call via `kernelPackages.callPackage`.
{
  lib,
  stdenv,
  fetchzip,
  kernel,
  kernelModuleMakeFlags,
  kmod,
  pahole,
  udevCheckHook,
  bash,
}:

stdenv.mkDerivation (finalAttrs: {
  pname = "tuxedo-drivers-${kernel.version}";
  version = "4.25.0";

  src = fetchzip {
    url = "https://gitlab.com/tuxedocomputers/development/packages/tuxedo-drivers/-/archive/v${finalAttrs.version}/tuxedo-drivers-v${finalAttrs.version}.tar.gz";
    hash = "sha256-AER+JPl3lem1OFV51VdOZAnr3Uy1BFSpEJNrE+shYis=";
  };

  # - `cp -r usr /` would install into the build machine's root.
  # - The recipes paste $(MAKEFLAGS) into the shell command line, which breaks
  #   on the kernel's `cmd_sign=...$(space)$@` flag (bash sees `$$(space)`).
  #   The sub-make inherits the flags via the MAKEFLAGS environment anyway.
  postPatch = ''
    substituteInPlace Makefile \
      --replace-fail 'cp -r usr /' "" \
      --replace-fail ' $(MAKEFLAGS)' ""
  '';

  postInstall = ''
    # modules_install runs depmod here; NixOS generates these for the whole
    # module tree, and copies in this package collide with the kernel's.
    rm -f $out/lib/modules/*/modules.*
    substituteInPlace files/usr/lib/udev/rules.d/* \
      --replace-quiet "/bin/bash" "${lib.getExe bash}" \
      --replace-quiet "/bin/sh" "${lib.getExe bash}"
    install -Dm 0644 -t $out/etc/udev/rules.d files/usr/lib/udev/rules.d/*
  '';

  # pahole is a build tool; in nixpkgs it is in buildInputs, which makes it
  # (and its closure) a host dependency that gets rebuilt for clang-built
  # kernels (pkgsLLVM).
  nativeBuildInputs = [
    kmod
    pahole
    udevCheckHook
  ]
  ++ kernel.moduleBuildDependencies;

  makeFlags = kernelModuleMakeFlags ++ [
    "KERNELRELEASE=${kernel.modDirVersion}"
    "KDIR=${kernel.dev}/lib/modules/${kernel.modDirVersion}/build"
    "INSTALL_MOD_PATH=${placeholder "out"}"
  ];

  doInstallCheck = true;

  meta = {
    description = "Keyboard and hardware I/O driver for TUXEDO Computers laptops";
    homepage = "https://gitlab.com/tuxedocomputers/development/packages/tuxedo-drivers";
    license = lib.licenses.gpl2Plus;
    platforms = lib.platforms.linux;
    broken = stdenv.hostPlatform.isAarch64 || (lib.versionOlder kernel.version "5.5");
  };
})
