{
  programs.git = {
    enable = true;
  };

  programs.emacs = {
    enable = true;
    extraPackages = epkgs: with epkgs; [
      elixir-mode
      lsp-mode
      cider
      company
      company-nixos-options
      deadgrep
      humanoid-themes
      magit
      nix-mode
      paredit
      projectile
      rainbow-delimiters
      selectrum
      selectrum-prescient
      whitespace-cleanup-mode
    ];
  };

  home.file = {
    ".emacs.d" = {
      source = ../emacs;
      recursive = true;
    };
  };

  services.gpg-agent = {
    enable = true;
    enableSshSupport = true;
  };
}
