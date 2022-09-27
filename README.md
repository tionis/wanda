# Glyph
> NOTICE: This tool is in a very early alpha state and is still being designed.

Glyph is commandline tool that manages a "personal archive" for you. This personal archive is a git repository which holds your data and can also define modules that glyph loads and integrates. There are a few default modules that are always active.  
The default wiki module of this application is kind of a commandline equivalent of Obsidian or can also be seen as a wrapper for other wiki helpers like vimwiki and uses git for syncing of different machines as well as versioning of the documents.  

## Modules
In the future the wiki will be one of multiple (optional) modules including:  
- config managment
- device crypto-key managment
- the wiki itself
- timers
- many more

## Roadmap
Following features are also on the roadmap:
- neovim plugin for tighter integration
- termux integration with automated setup script for android support

## Future Ideas
And these features are currently in discussion and may be implmeneted:
- embedded editor

## Documentation
Large parts of glyph are self documenting via the cli and --help flags, following things should be noted:  
- Glyph discoveres the git repo it should work on first by looking up the `GLYPH_ARCH_DIR` environment variable and defaults to `$HOME/arch` if not

## Contact Me
If anyone relies on this tool, please inform me over [any communication channel](https://tionis.dev) (including GitHub issues) so that I don't push a change that crashes your workflow.
