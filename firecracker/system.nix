{ nixpkgs, isContainer, figlet-fonts } :
{ pkgs, config, lib, ... }:

let
  kernel = pkgs.linux_5_12;
  keys = import ../keys.nix;
  ports = {
    ttyd = 7681;
  };

in {
  systemd.services.ttyd = {
    description = "ttyd Web Server Daemon";

    wantedBy = [ "multi-user.target" ];

    serviceConfig = {
      User = "root";
    };

    script = let
    in ''
      PASSWORD=$(cat /password)
      ${pkgs.ttyd}/bin/ttyd \
        --credential user:"$PASSWORD" \
        --port ${toString ports.ttyd} \
        ${pkgs.shadow}/bin/login -f user
    '';
  };

  services = {
    getty.autologinUser = "root";
    openssh.enable = true;
    tailscale.enable = true;

    # ttyd = {
    #   enable = true;
    #   port = ports.ttyd;
    #   username = "user";
    #   passwordFile = "/password";
    #   clientOptions = {
    #     fontSize = "16";
    #   };
    # };

    nginx = {
      enable = true;
      virtualHosts = {
        tty = {
          serverName = "*.tty.node.town";
          locations = {
            "/" = {
              proxyPass = "http://127.0.0.1:${toString ports.ttyd}/";
              proxyWebsockets = true;
            };
          };
        };

        dev = {
          serverName = "dev.*";
          root = (pkgs.linkFarmFromDrvs "webroot" [
            (pkgs.writeTextFile {
              name = "index.html";
              text = ''
                <!doctype html>
                <b style="margin: 8em auto;">Hello.</b>
              '';
            })
          ]);
        };
      };
    };
  };

  programs.bash.promptInit = ''
    if [ "$TERM" != "dumb" -o -n "$INSIDE_EMACS" ]; then
      PS1=$'\[\e[1m\]\h\[\e[0m\]:\w\[\e[1m\]`eval "$PS1GIT"`\[\e[0m\]\$ '
      PS1GIT='[[ `git status --short 2>/dev/null` ]] && echo \*'
      [[ $TERM = xterm* ]] && PS1='\[\033]2;\h:\w\007\]'"$PS1"
    fi
  '';

  environment.interactiveShellInit = ''
    ${pkgs.figlet}/bin/figlet -f ${figlet-fonts}/Jazmine.flf node.town \
      | ${pkgs.lolcat}/bin/lolcat
    echo
    '';

  users.users = {
    root = {
      initialHashedPassword = "";
      openssh.authorizedKeys.keys = [keys.mbrock-ssh];
    };

    mbrock = {
      isNormalUser = true;
      extraGroups = ["wheel"];
      openssh.authorizedKeys.keys = [keys.mbrock-ssh];
    };

    user = {
      isNormalUser = true;
      initialHashedPassword = "";
      extraGroups = ["wheel"];
      openssh.authorizedKeys.keys = [keys.mbrock-ssh];
    };
  };

  security.sudo.wheelNeedsPassword = false;

  home-manager =  {
    useGlobalPkgs = true;
    useUserPackages = true;
    users.mbrock = import ../mbrock.nix;
    users.user = import ./user.nix;
  };

  networking = {
    hostName = ""; # set from dhcp
    dhcpcd.enable = true;
    firewall.allowPing = true;
    useHostResolvConf = false;
    usePredictableInterfaceNames = false;
    enableIPv6 = false;
    interfaces.eth0.useDHCP = true;
  };

  system.activationScripts = {
    makePassword = ''
      if [ ! -f /password ]; then
        ${pkgs.apg}/bin/apg -M L -n 1 -m 9 -x 9 > /password
      fi
      echo "Rig password: $(cat /password)"
    '';

    makeWebroot = ''
      mkdir -p /www
      chown user /www
    '';

    installInitScript = ''
      mkdir -p /sbin
      ln -fs $systemConfig/init /sbin/init
    '';
  };

  environment.systemPackages = with pkgs; [
    clojure
    ruby
    nethack
    figlet
    lolcat
  ];

  boot.isContainer = isContainer;

  boot.loader.grub.enable = false;
  fileSystems."/" = { device = "/dev/vda"; };

  system.build.rootfs = nixpkgs.lib.makeDiskImage {
    inherit pkgs config lib;
    name = "firecracker-rootfs";
    partitionTableType = "none";
  };

  nix = {
    package = pkgs.nixUnstable;
    extraOptions = ''
      experimental-features = nix-command flakes
    '';
  };

  nix.registry.nixpkgs.flake = nixpkgs;

  boot.kernelPackages = pkgs.linuxPackages_custom {
    inherit (kernel) src version;
    configfile = ./kernel.config;
  };

  environment.variables.NIX_REMOTE = lib.mkForce "";

  boot.postBootCommands =
    ''
      # After booting, register the contents of the Nix store in the Nix
      # database.
      if [ -f /nix-path-registration ]; then
        ${config.nix.package.out}/bin/nix-store --load-db \
          < /nix-path-registration &&
        rm /nix-path-registration
      fi
      # nixos-rebuild also requires a "system" profile
      ${config.nix.package.out}/bin/nix-env -p /nix/var/nix/profiles/system \
        --set /run/current-system
    '';

}
