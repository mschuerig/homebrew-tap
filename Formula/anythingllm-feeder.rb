# anythingllm-feeder
#
# This formula is patched automatically by the `release` workflow in
# mschuerig/anythingllm-feeder when a `v*` tag is pushed. The workflow
# replaces `url` and `sha256` below and commits the result here.
# Don't edit `url` / `sha256` by hand for routine releases.

class AnythingllmFeeder < Formula
  desc "Extract docs/videos to Markdown (forage) and feed AnythingLLM (ingest)"
  homepage "https://github.com/mschuerig/anythingllm-feeder"
  url "https://github.com/mschuerig/anythingllm-feeder/archive/refs/tags/v0.2.1.tar.gz"
  sha256 "d913e2a2c11f9006dcf8e08d1cbf42f9e47508b78738453eea1a919d70680906"
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
      # Install the project with its core dependencies only
      # (httpx + send2trash + shtab). The heavy ML extras (docling,
      # mlx-whisper) are NOT in the brew bundle — they're installed by
      # the user post-install via `forage install-extras`, which runs
      # the venv's pip outside brew's sandbox. The brew approach can't
      # carry them cleanly: their wheels collide with brew's Mach-O
      # relocator (rpds-py headerpad), and the sandbox-bound build
      # alternative fails because Cargo can't write to ~/.cargo.
      system libexec/"bin/python", "-m", "pip", "install",
             "--no-cache-dir", "-v", "."
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
      This brew install ships only the small core (httpx + send2trash +
      shtab) so `ingest` can sync and `forage` can manage collections of
      already-extracted Markdown. For PDF/Office extraction and
      audio/video transcription, install the heavy extras into this
      formula's venv:

        forage install-extras

      That pulls in docling (PDF/Office) and mlx-whisper (Apple Silicon
      transcription) via pip — about 3–5 GB, mostly PyTorch. The download
      runs outside brew, so the install completes cleanly. Re-run after
      `brew upgrade anythingllm-feeder` since each version installs into
      a fresh venv.

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
