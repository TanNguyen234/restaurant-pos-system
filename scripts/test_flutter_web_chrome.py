import time
from playwright.sync_api import sync_playwright

def main():
    with sync_playwright() as p:
        browser = p.chromium.launch(
            executable_path=r"C:\Program Files\Google\Chrome\Application\chrome.exe",
            headless=True
        )
        context = browser.new_context(
            viewport={"width": 412, "height": 915},
            is_mobile=True,
            user_agent="Mozilla/5.0 (Linux; Android 13; Pixel 7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Mobile Safari/537.36"
        )
        page = context.new_page()

        console_logs = []
        page.on("console", lambda msg: console_logs.append(f"[{msg.type}] {msg.text}"))
        page.on("pageerror", lambda err: console_logs.append(f"[ERROR] {err}"))

        print("Navigating to http://localhost:8080...")
        page.goto("http://localhost:8080", wait_until="domcontentloaded")
        
        # Wait up to 15 seconds for Flutter to bootstrap
        for i in range(15):
            time.sleep(1)
            has_view = page.evaluate("() => document.querySelector('flutter-view') !== null || document.querySelector('flt-glass-pane') !== null")
            if has_view:
                print(f"Flutter rendered after {i+1} seconds!")
                break
        
        time.sleep(2)
        page.screenshot(path="artifacts/chrome_devtools_test_flutter.png")
        print("Screenshot saved to artifacts/chrome_devtools_test_flutter.png")
        print("Console logs count:", len(console_logs))
        for log in console_logs[-10:]:
            print("  ", log)

        browser.close()

if __name__ == "__main__":
    main()
