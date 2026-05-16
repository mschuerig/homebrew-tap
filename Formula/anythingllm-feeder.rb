# anythingllm-feeder
#
# This formula is patched automatically by the `release` workflow in
# mschuerig/anythingllm-feeder when a `v*` tag is pushed. The workflow
# replaces `url` and `sha256` below and commits the result here.
# Don't edit `url` / `sha256` by hand for routine releases.

class AnythingllmFeeder < Formula
  desc "Extract docs/videos to Markdown (forage) and feed AnythingLLM (ingest)"
  homepage "https://github.com/mschuerig/anythingllm-feeder"
  url "https://github.com/mschuerig/anythingllm-feeder/archive/refs/tags/v0.1.0.tar.gz"
  sha256 "0000000000000000000000000000000000000000000000000000000000000000"
  license "MIT"
  head "https://github.com/mschuerig/anythingllm-feeder.git", branch: "main"

  depends_on "ffmpeg"
  depends_on "python@3.12"
  depends_on :macos
  depends_on arch: :arm64

  def install
    # We avoid `Language::Python::Virtualenv` and its `virtualenv_create`
    # helper deliberately: that path bootstraps pip in a way that silently
    # dies under brew's sandbox when pip is invoked with non-trivial deps
    # (it produced an empty log on the GitHub Actions runner). A plain
    # `python -m venv` + `python -m pip install` works.
    #
    # `--no-cache-dir` keeps pip from writing to ~/Library/Caches/pip,
    # which brew's sandbox would block during `brew install`. Without it,
    # pip's cache-write attempts seem to crash the process silently.
    python = Formula["python@3.12"].opt_bin/"python3.12"
    system python, "-m", "venv", libexec
    cd buildpath do
      # We use the PyPI wheels (no `--no-binary` flag). One transitive
      # dep — rpds-py via jsonschema → docling — ships a wheel whose
      # Mach-O headerpad is too small for brew's post-install dylib
      # relocator to rewrite the install ID to our keg's long absolute
      # path. Brew prints "Failed to fix install linkage" and exits
      # non-zero, but the install otherwise completes (the keg is poured
      # in full). Python extensions are loaded by filesystem path, not
      # install ID, so this warning is cosmetic. See caveats.
      #
      # We tried `--no-binary rpds-py` to build it with proper
      # headerpad, but brew's build sandbox blocks Cargo's writes to
      # ~/.cargo and the source build fails before we get anywhere.
      system libexec/"bin/python", "-m", "pip", "install",
             "--no-cache-dir", "-v", ".[all]"
    end

    bin.install_symlink libexec/"bin/forage"
    bin.install_symlink libexec/"bin/ingest"

    generate_completions_from_executable(bin/"forage", "--print-completion",
                                         shells: [:bash, :zsh])
    generate_completions_from_executable(bin/"ingest", "--print-completion",
                                         shells: [:bash, :zsh])

    man1.install "man/forage.1", "man/ingest.1"
  end

  def caveats
    <<~EOS
      Bundle includes docling (PDF/Office extraction) and mlx-whisper
      (audio/video transcription). First install pulls about 3–5 GB from
      PyPI because docling brings in PyTorch. mlx-whisper requires Apple
      Silicon.

      Brew may print "Failed to fix install linkage" near the end of the
      install. This is a COSMETIC warning about one Python C extension
      (rpds-py) whose wheel is built with insufficient Mach-O headerpad.
      Python loads extensions by filesystem path, not install ID, so the
      warning has no runtime effect — `forage` and `ingest` work fine.

      Data directory — preserved across `brew upgrade` and `brew uninstall`:
        ~/Library/Application Support/anythingllm-feeder/

      To wipe collections and state before uninstalling:
        forage purge          # synonym: ingest purge

      Both move the data root to Trash. Recover via Finder → Trash → Put Back.

      `ingest` expects a local AnythingLLM at http://localhost:3001 and an
      API key in $ANYTHINGLLM_API_KEY. See `man ingest`.

      Model weights downloaded on first transcription live under
      ~/.cache/huggingface/hub/. They are SHARED with any other Hugging Face
      tool on your system and are NOT removed by `brew uninstall` or
      `forage purge`. If anythingllm-feeder was the only thing using them
      you can clear the space with:
        rm -rf ~/.cache/huggingface/hub
    EOS
  end

  test do
    assert_match "forage", shell_output("#{bin}/forage --version")
    assert_match "ingest", shell_output("#{bin}/ingest --version")
    assert_match "_shtab_forage", shell_output("#{bin}/forage --print-completion bash")
  end
end
