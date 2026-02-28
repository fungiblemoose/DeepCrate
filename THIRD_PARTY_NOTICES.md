# Third-Party Notices

DeepCrate includes and depends on third-party libraries. Each dependency is
licensed by its respective authors under its own terms.

This file is a practical summary for maintainers and distributors. It does not
replace any upstream license text.

## Python Runtime Dependencies

| Package | License | Upstream |
| --- | --- | --- |
| typer | MIT | https://github.com/fastapi/typer |
| rich | MIT | https://github.com/Textualize/rich |
| librosa | ISC | https://github.com/librosa/librosa |
| python-soundfile | BSD 3-Clause | https://github.com/bastibe/python-soundfile |
| mutagen | GPL-2.0-or-later | https://github.com/quodlibet/mutagen |
| openai | Apache-2.0 | https://github.com/openai/openai-python |
| spotipy | MIT | https://github.com/plamere/spotipy |
| pydantic-settings | MIT | https://github.com/pydantic/pydantic-settings |
| aiosqlite | MIT | https://github.com/omnilib/aiosqlite |
| numpy | BSD 3-Clause (with bundled component notices) | https://numpy.org |
| PySide6 | LGPL-3.0-only OR GPL-2.0-only OR GPL-3.0-only | https://pyside.org |

## Distribution Notes

- If you distribute DeepCrate binaries, ensure all required third-party license
  notices are shipped with your distribution.
- Some optional/legacy components (for example `mutagen` and `PySide6`) use
  copyleft licenses. Verify compliance requirements for your specific
  distribution model.
- For authoritative terms, consult each dependency's upstream license files.
