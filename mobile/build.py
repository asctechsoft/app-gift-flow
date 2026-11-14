"""Build, version-bump and distribute an APK. Run from this folder:

    python build.py                 # menu
    python build.py dev release     # flavor + build type
    python build.py check-strings   # only the translation key check

Same tooling as muvik / smart_drink (see tool/build/build_helper.py). No secret
lives in the repo: Telegram / e-mail / Firebase service account come from env
vars or the git-ignored tool/build/build_secrets.json and build_auth.json.
"""
import os
import sys

PROJECT_DIR = os.path.dirname(os.path.abspath(__file__))
os.chdir(PROJECT_DIR)
sys.path.insert(0, os.path.join(PROJECT_DIR, "tool", "build"))

from build_helper import main_build  # noqa: E402

if __name__ == "__main__":
    main_build(
        argv=sys.argv,
        package_name="com.asc.gift_flow",
        # Same recipients as muvik / smart_drink. Override with ASC_TESTER_EMAILS,
        # ASC_EMAIL_TO, ASC_EMAIL_FROM. E-mail password: ASC_EMAIL_PASSWORD or
        # tool/build/build_secrets.json.
        tester_emails="asctechsoft888@gmail.com",
        email_to="dsp.entertainment.99@gmail.com",
        email_from="dsp.entertainment.99@gmail.com",
    )
