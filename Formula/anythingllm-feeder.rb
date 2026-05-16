# anythingllm-feeder
#
# This formula is patched automatically by the `release` workflow in
# mschuerig/anythingllm-feeder when a `v*` tag is pushed. The workflow
# replaces `url` and `sha256` below and commits the result here.
# Don't edit `url` / `sha256` by hand for routine releases.

class AnythingllmFeeder < Formula
  include Language::Python::Virtualenv

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
    # virtualenv_create gives us a brew-managed venv at libexec/ (so
    # brew auto-rebuilds when python@3.12 is upgraded). Don't use
    # `venv.pip_install` — it passes `--no-deps`, expecting each
    # dependency as a separate `resource` block. We deliberately skip
    # that pattern (torch / mlx are wheel-only and don't fit brew's
    # sdist-resource convention), so we run pip directly and let it
    # resolve PyPI normally.
    virtualenv_create(libexec, "python3.12")
    system libexec/"bin/pip", "install", "-v", "#{buildpath}[all]"

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
