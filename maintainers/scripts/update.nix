{ package ? null
, maintainer ? null
, path ? null
, max-workers ? null
, include-overlays ? false
, keep-going ? null
, commit ? null
}:

# TODO: add assert statements

let
  pkgs = import ./../../default.nix (
    if include-overlays == false then
      { overlays = []; }
    else if include-overlays == true then
      { } # Let Nixpkgs include overlays impurely.
    else { overlays = include-overlays; }
  );

  inherit (pkgs) lib;

  /* Remove duplicate elements from the list based on some extracted value. O(n^2) complexity.
   */
  nubOn = f: list:
    if list == [] then
      []
    else
      let
        x = lib.head list;
        xs = lib.filter (p: f x != f p) (lib.drop 1 list);
      in
        [x] ++ nubOn f xs;

  packagesWithPath = rootPath: cond: pkgs:
    let
      packagesWithPathInner = relativePath: pathContent:
        let
          result = builtins.tryEval pathContent;

          dedupResults = lst: nubOn ({ package, attrPath }: package.updateScript) (lib.concatLists lst);
        in
          if result.success then
            let
              pathContent = result.value;
            in
              if lib.isDerivation pathContent then
                lib.optional (cond relativePath pathContent) { attrPath = lib.concatStringsSep "." relativePath; package = pathContent; }
              else if lib.isAttrs pathContent then
                # If user explicitly points to an attrSet or it is marked for recursion, we recur.
                if relativePath == rootPath || pathContent.recurseForDerivations or false || pathContent.recurseForRelease or false then
                  dedupResults (lib.mapAttrsToList (name: elem: packagesWithPathInner (relativePath ++ [name]) elem) pathContent)
                else []
              else if lib.isList pathContent then
                dedupResults (lib.imap0 (i: elem: packagesWithPathInner (relativePath ++ [i]) elem) pathContent)
              else []
          else [];
    in
      packagesWithPathInner rootPath pkgs;

  packagesWith = packagesWithPath [];

  packagesWithUpdateScriptAndMaintainer = maintainer':
    let
      maintainer =
        if ! builtins.hasAttr maintainer' lib.maintainers then
          builtins.throw "Maintainer with name `${maintainer'} does not exist in `maintainers/maintainer-list.nix`."
        else
          builtins.getAttr maintainer' lib.maintainers;
    in
      packagesWith (relativePath: pkg: builtins.hasAttr "updateScript" pkg &&
                                 (if builtins.hasAttr "maintainers" pkg.meta
                                   then (if builtins.isList pkg.meta.maintainers
                                           then builtins.elem maintainer pkg.meta.maintainers
                                           else maintainer == pkg.meta.maintainers
                                        )
                                   else false
                                 )
                   )
                   pkgs;

  packagesWithUpdateScript = path:
    let
      prefix = lib.splitString "." path;
      pathContent = lib.attrByPath prefix null pkgs;
    in
      if pathContent == null then
        builtins.throw "Attribute path `${path}` does not exists."
      else
        packagesWithPath prefix (relativePath: pkg: builtins.hasAttr "updateScript" pkg)
                       pathContent;

  packageByName = name:
    let
        package = lib.attrByPath (lib.splitString "." name) null pkgs;
    in
      if package == null then
        builtins.throw "Package with an attribute name `${name}` does not exists."
      else if ! builtins.hasAttr "updateScript" package then
        builtins.throw "Package with an attribute name `${name}` does not have a `passthru.updateScript` attribute defined."
      else
        { attrPath = name; inherit package; };

  packages =
    if package != null then
      [ (packageByName package) ]
    else if maintainer != null then
      packagesWithUpdateScriptAndMaintainer maintainer
    else if path != null then
      packagesWithUpdateScript path
    else
      builtins.throw "No arguments provided.\n\n${helpText}";

  helpText = ''
    Please run:

        % nix-shell maintainers/scripts/update.nix --argstr maintainer garbas

    to run all update scripts for all packages that lists \`garbas\` as a maintainer
    and have \`updateScript\` defined, or:

        % nix-shell maintainers/scripts/update.nix --argstr package gnome3.nautilus

    to run update script for specific package, or

        % nix-shell maintainers/scripts/update.nix --argstr path gnome3

    to run update script for all package under an attribute path.

    You can also add

        --argstr max-workers 8

    to increase the number of jobs in parallel, or

        --argstr keep-going true

    to continue running when a single update fails.

    You can also make the updater automatically commit on your behalf from updateScripts
    that support it by adding

        --argstr commit true
  '';

  packageData = { package, attrPath }: {
    name = package.name;
    pname = lib.getName package;
    oldVersion = lib.getVersion package;
    updateScript = map builtins.toString (lib.toList (package.updateScript.command or package.updateScript));
    supportedFeatures = package.updateScript.supportedFeatures or [];
    attrPath = package.updateScript.attrPath or attrPath;
  };

  packagesJson = pkgs.writeText "packages.json" (builtins.toJSON (map packageData packages));

  optionalArgs =
    lib.optional (max-workers != null) "--max-workers=${max-workers}"
    ++ lib.optional (keep-going == "true") "--keep-going"
    ++ lib.optional (commit == "true") "--commit";

  args = [ packagesJson ] ++ optionalArgs;

in pkgs.stdenv.mkDerivation {
  name = "nixpkgs-update-script";
  buildCommand = ''
    echo ""
    echo "----------------------------------------------------------------"
    echo ""
    echo "Not possible to update packages using \`nix-build\`"
    echo ""
    echo "${helpText}"
    echo "----------------------------------------------------------------"
    exit 1
  '';
  shellHook = ''
    unset shellHook # do not contaminate nested shells
    exec ${pkgs.python3.interpreter} ${./update.py} ${builtins.concatStringsSep " " args}
  '';
}
