#!/usr/bin/env python3
"""
HTTP Notification Server for Linux
Accepts GET requests with URL parameters and shows notifications via notify-send
Properly handles UTF-8/Russian text
"""

import http.server
import socketserver
import subprocess
import urllib.parse
import os
import sys
from pathlib import Path
from typing import Optional, Dict
import argparse
import signal
import traceback
import json

class NotificationSender:
    """Notification sender via notify-send"""
    
    def __init__(self, icons_dir: str = "."):
        """
        Initialize notification sender
        
        Args:
            icons_dir: Directory for icon search
        """
        self.icons_dir = Path(icons_dir).resolve()
        self.check_dependencies()
    
    def check_dependencies(self):
        """Check if notify-send is available"""
        try:
            result = subprocess.run(
                ["which", "notify-send"], 
                capture_output=True, 
                text=True,
                check=True
            )
            print(f"✅ notify-send found: {result.stdout.strip()}")
            return True
        except subprocess.CalledProcessError:
            print("❌ Error: notify-send not found!")
            print("\nInstall notify-send:")
            print("  Ubuntu/Debian: sudo apt install libnotify-bin")
            print("  Fedora/RHEL:   sudo dnf install libnotify")
            print("  Arch:          sudo pacman -S libnotify")
            return False
    
    def test_notification(self):
        """Test notification sending directly"""
        print("\n🧪 Testing notification sending...")
        try:
            # Test with Russian text
            cmd = ["notify-send", "Тест сервера", "Если вы видите это, notify-send работает!"]
            result = subprocess.run(cmd, capture_output=True, text=True, encoding='utf-8')
            if result.returncode == 0:
                print("✅ Test notification sent successfully!")
                return True
            else:
                print(f"❌ Error: {result.stderr}")
                return False
        except Exception as e:
            print(f"❌ Exception: {e}")
            return False
    
    def find_icon(self, icon_name: str) -> Optional[str]:
        """
        Search for icon in current directory
        
        Args:
            icon_name: Icon name
            
        Returns:
            Full path to icon or None if not found
        """
        if not icon_name:
            return None
            
        # Decode URL-encoded icon name
        icon_name = urllib.parse.unquote(icon_name)
        
        # If absolute path is provided
        if os.path.isabs(icon_name) and os.path.exists(icon_name):
            return icon_name
        
        # Search in current directory
        possible_names = [
            icon_name,
            f"{icon_name}.png",
            f"{icon_name}.svg",
            f"{icon_name}.jpg",
            f"{icon_name}.jpeg",
            f"{icon_name}.ico"
        ]
        
        for name in possible_names:
            # Check in specified icons directory
            icon_path = self.icons_dir / name
            if icon_path.exists():
                print(f"✅ Found icon: {icon_path}")
                return str(icon_path)
            
            # Check in current server directory
            if os.path.exists(name):
                abs_path = os.path.abspath(name)
                print(f"✅ Found icon: {abs_path}")
                return abs_path
        
        print(f"⚠️  Icon '{icon_name}' not found, using as system icon name")
        return icon_name
    
    def decode_parameter(self, param: str) -> str:
        """Properly decode URL parameter for UTF-8/Russian text"""
        if not param:
            return param
        
        try:
            # First try to decode as UTF-8
            decoded = urllib.parse.unquote(param, encoding='utf-8')
            return decoded
        except:
            try:
                # Fall back to latin-1
                decoded = urllib.parse.unquote(param, encoding='latin-1')
                return decoded
            except:
                # Last resort - replace with empty
                return ""
    
    def send_notification(self, params: Dict[str, str]) -> Dict[str, str]:
        """
        Send notification based on URL parameters
        
        Args:
            params: Dictionary of URL parameters
            
        Returns:
            Dictionary with sending result
        """
        try:
            print(f"\n📨 Received parameters: {params}")
            
            # Extract and properly decode parameters
            title = self.decode_parameter(params.get("title", "Уведомление"))
            message = self.decode_parameter(params.get("message", ""))
            icon = params.get("icon", "")
            urgency = params.get("urgency", "normal")
            
            # Parse timeout (time in milliseconds)
            try:
                timeout = int(params.get("timeout", "5000"))
            except ValueError:
                timeout = 5000
            
            print(f"📝 Creating notification:")
            print(f"   Title: {title}")
            print(f"   Message: {message}")
            print(f"   Icon: {icon}")
            print(f"   Urgency: {urgency}")
            print(f"   Timeout: {timeout}ms")
            
            # Ensure strings are properly encoded for subprocess
            title_encoded = title.encode('utf-8').decode('utf-8', 'ignore')
            message_encoded = message.encode('utf-8').decode('utf-8', 'ignore')
            
            # Prepare notify-send command
            cmd = [
                "notify-send",
                title_encoded,
                message_encoded,
                "-u", urgency,
                "-t", str(timeout)
            ]
            
            # Add icon if specified
            if icon:
                icon_path = self.find_icon(icon)
                if icon_path:
                    cmd.extend(["-i", icon_path])
                    print(f"🔍 Using icon: {icon_path}")
            
            # Add category if specified
            category = params.get("category", "")
            if category:
                category_decoded = self.decode_parameter(category)
                cmd.extend(["-c", category_decoded])
            
            # Print command for debugging
            print(f"🔧 Command: {' '.join(cmd)}")
            
            # Execute command with proper encoding
            result = subprocess.run(
                cmd,
                capture_output=True,
                text=True,
                encoding='utf-8',
                errors='replace'
            )
            
            print(f"📤 Execution result:")
            print(f"   Return code: {result.returncode}")
            if result.stdout:
                print(f"   Output: {result.stdout}")
            if result.stderr:
                print(f"   Error: {result.stderr}")
            
            if result.returncode == 0:
                return {
                    "status": "success",
                    "message": f"Notification sent: {title}",
                    "debug": {
                        "command": " ".join(cmd),
                        "returncode": result.returncode,
                        "title_original": title,
                        "title_encoded": title_encoded
                    }
                }
            else:
                return {
                    "status": "error",
                    "message": f"notify-send error: {result.stderr}",
                    "debug": {
                        "command": " ".join(cmd),
                        "returncode": result.returncode,
                        "stderr": result.stderr
                    }
                }
                
        except Exception as e:
            print(f"❌ Exception while sending: {traceback.format_exc()}")
            return {
                "status": "error",
                "message": f"Processing error: {str(e)}"
            }


class NotificationHTTPHandler(http.server.BaseHTTPRequestHandler):
    """HTTP handler for notifications"""
    
    def __init__(self, *args, **kwargs):
        self.notification_sender = kwargs.pop('notification_sender')
        super().__init__(*args, **kwargs)
    
    def do_GET(self):
        """Handle GET requests"""
        try:
            print(f"\n🔗 Received request from {self.client_address[0]}")
            print(f"   Method: GET")
            print(f"   Path: {self.path}")
            print(f"   Raw path: {repr(self.path)}")
            
            # Parse URL
            parsed_url = urllib.parse.urlparse(self.path)
            print(f"   Parsed path: {parsed_url.path}")
            print(f"   Query string: {parsed_url.query}")
            
            # Parse query string with proper encoding
            query_params = urllib.parse.parse_qs(parsed_url.query, encoding='utf-8')
            
            # Convert lists to single values
            params = {k: v[0] if v else "" for k, v in query_params.items()}
            
            # Log raw parameters for debugging
            print(f"   Raw params: {params}")
            
            # Handle special paths
            if parsed_url.path == "/favicon.ico":
                self.send_response(204)
                self.end_headers()
                return
            
            if parsed_url.path == "/test":
                # Test page
                self.send_response(200)
                self.send_header('Content-type', 'text/html; charset=utf-8')
                self.end_headers()
                
                html = """
                <!DOCTYPE html>
                <html>
                <head>
                    <meta charset="UTF-8">
                    <title>Тест сервера</title>
                </head>
                <body>
                    <h1>Тест сервера уведомлений</h1>
                    <button onclick="sendTest()">Отправить тестовое уведомление</button>
                    <div id="result"></div>
                    <script>
                        function sendTest() {
                            // Test with Russian text
                            var title = encodeURIComponent('Тестовое уведомление');
                            var message = encodeURIComponent('Проверка работы с русским текстом');
                            fetch('/notify?title=' + title + '&message=' + message)
                                .then(response => response.text())
                                .then(html => {
                                    document.getElementById('result').innerHTML = html;
                                });
                        }
                    </script>
                </body>
                </html>
                """
                self.wfile.write(html.encode('utf-8'))
                return
            
            if parsed_url.path == "/" or parsed_url.path == "/notify":
                # Send notification
                result = self.notification_sender.send_notification(params)
                
                # Send response
                self.send_response(200)
                self.send_header('Content-type', 'text/html; charset=utf-8')
                self.send_header('Access-Control-Allow-Origin', '*')
                self.end_headers()
                
                # Create HTML response
                if result["status"] == "success":
                    html = """
                    <!DOCTYPE html>
                    <html>
                    <head>
                        <meta charset="UTF-8">
                        <title>Уведомление отправлено</title>
                        <style>
                            body {{ font-family: Arial, sans-serif; margin: 40px; }}
                            .success {{ color: green; }}
                            .debug {{ background: #f0f0f0; padding: 10px; margin: 10px 0; }}
                        </style>
                    </head>
                    <body>
                        <h1 class="success">✅ Уведомление успешно отправлено!</h1>
                        <p>{message}</p>
                        <div class="debug">
                            <h3>Отладочная информация:</h3>
                            <pre>{debug}</pre>
                        </div>
                        <p><a href="/">Назад</a> | <a href="/test">Тест</a></p>
                    </body>
                    </html>
                    """.format(
                        message=result["message"],
                        debug=json.dumps(result.get("debug", {}), indent=2, ensure_ascii=False)
                    )
                else:
                    html = """
                    <!DOCTYPE html>
                    <html>
                    <head>
                        <meta charset="UTF-8">
                        <title>Ошибка отправки</title>
                        <style>
                            body {{ font-family: Arial, sans-serif; margin: 40px; }}
                            .error {{ color: red; }}
                            .debug {{ background: #f0f0f0; padding: 10px; margin: 10px 0; }}
                        </style>
                    </head>
                    <body>
                        <h1 class="error">❌ Ошибка отправки уведомления</h1>
                        <p>{message}</p>
                        <div class="debug">
                            <h3>Отладочная информация:</h3>
                            <pre>{debug}</pre>
                        </div>
                        <p><a href="/">Назад</a> | <a href="/test">Тест</a></p>
                    </body>
                    </html>
                    """.format(
                        message=result["message"],
                        debug=json.dumps(result.get("debug", {}), indent=2, ensure_ascii=False)
                    )
                
                self.wfile.write(html.encode('utf-8'))
                
            else:
                # Show example page
                self.send_response(200)
                self.send_header('Content-type', 'text/html; charset=utf-8')
                self.end_headers()
                
                html = """
                <!DOCTYPE html>
                <html>
                <head>
                    <meta charset="UTF-8">
                    <title>Сервер уведомлений</title>
                    <style>
                        body { font-family: Arial, sans-serif; margin: 40px; }
                        code { background: #f4f4f4; padding: 2px 5px; }
                        pre { background: #f4f4f4; padding: 10px; border-left: 3px solid #007bff; }
                        .example { margin: 20px 0; padding: 15px; background: #e9f7ff; }
                        .test-btn { background: #007bff; color: white; padding: 10px 15px; border: none; cursor: pointer; }
                        input, textarea { width: 300px; margin: 5px 0; padding: 5px; }
                    </style>
                </head>
                <body>
                    <h1>🚀 Сервер уведомлений</h1>
                    
                    <div class="example">
                        <h3>🧪 Быстрый тест:</h3>
                        <input type="text" id="testTitle" value="Тестовое уведомление" placeholder="Заголовок"><br>
                        <textarea id="testMessage" placeholder="Сообщение">Проверка работы с русским текстом</textarea><br>
                        <button class="test-btn" onclick="sendTest()">Отправить тестовое уведомление</button>
                        <div id="test-result"></div>
                    </div>
                    
                    <p>Используйте GET запросы для отправки уведомлений:</p>
                    
                    <div class="example">
                        <h3>📝 Примеры использования:</h3>
                        <pre>http://{host}/notify?title=Заголовок&message=Текст сообщения</pre>
                        
                        <h4>📋 Все параметры:</h4>
                        <ul>
                            <li><code>title</code> - Заголовок уведомления (URL-encoded)</li>
                            <li><code>message</code> - Текст уведомления (URL-encoded)</li>
                            <li><code>icon</code> - Иконка (файл в текущей директории)</li>
                            <li><code>urgency</code> - Срочность: low, normal, critical</li>
                            <li><code>timeout</code> - Время показа в мс (по умолчанию: 5000)</li>
                            <li><code>category</code> - Категория уведомления</li>
                        </ul>
                    </div>
                    
                    <div class="example">
                        <h3>🔧 Примеры запросов с русским текстом:</h3>
                        <p>Простое уведомление:</p>
                        <pre>curl "http://{host}/notify?title=%D0%9F%D1%80%D0%B8%D0%B2%D0%B5%D1%82&message=%D0%9C%D0%B8%D1%80!"</pre>
                        
                        <p>С иконкой:</p>
                        <pre>curl "http://{host}/notify?title=%D0%9E%D0%BF%D0%BE%D0%B2%D0%B5%D1%89%D0%B5%D0%BD%D0%B8%D0%B5&message=%D0%9F%D1%80%D0%BE%D0%B2%D0%B5%D1%80%D1%8C%D1%82%D0%B5+%D1%81%D0%B8%D1%81%D1%82%D0%B5%D0%BC%D1%83&icon=warning.png&urgency=critical"</pre>
                        
                        <p>Длительное уведомление:</p>
                        <pre>curl "http://{host}/notify?title=%D0%9D%D0%B0%D0%BF%D0%BE%D0%BC%D0%B8%D0%BD%D0%B0%D0%BD%D0%B8%D0%B5&message=%D0%92%D1%81%D1%82%D1%80%D0%B5%D1%87%D0%B0+%D1%87%D0%B5%D1%80%D0%B5%D0%B7+10+%D0%BC%D0%B8%D0%BD%D1%83%D1%82&timeout=10000"</pre>
                    </div>
                    
                    <script>
                        function sendTest() {{
                            var title = encodeURIComponent(document.getElementById('testTitle').value);
                            var message = encodeURIComponent(document.getElementById('testMessage').value);
                            fetch('/notify?title=' + title + '&message=' + message + '&urgency=critical')
                                .then(response => response.text())
                                .then(html => {{
                                    document.getElementById('test-result').innerHTML = html;
                                }});
                        }}
                    </script>
                </body>
                </html>
                """.format(host=self.headers.get('Host', 'localhost:80'))
                
                self.wfile.write(html.encode('utf-8'))
                
        except Exception as e:
            print(f"❌ Handler error: {traceback.format_exc()}")
            self.send_response(500)
            self.send_header('Content-type', 'text/plain; charset=utf-8')
            self.end_headers()
            self.wfile.write(f"Internal server error: {str(e)}".encode('utf-8'))
    
    def log_message(self, format, *args):
        """Disable default logging"""
        pass


class NotificationServer:
    """HTTP server for notifications"""
    
    def __init__(self, bind_host: str = "", port: int = 80, icons_dir: str = "."):
        """
        Initialize server
        
        Args:
            bind_host: Host to bind to
            port: Port to listen on
            icons_dir: Directory with icons
        """
        self.bind_host = bind_host
        self.port = port
        self.server = None
        self.notification_sender = NotificationSender(icons_dir)
    
    def start(self):
        """Start HTTP server"""
        try:
            # Create custom handler with notification_sender
            handler_class = lambda *args, **kwargs: NotificationHTTPHandler(
                *args, notification_sender=self.notification_sender, **kwargs
            )
            
            self.server = socketserver.TCPServer(
                (self.bind_host, self.port),
                handler_class,
                bind_and_activate=False
            )
            
            # Allow address reuse
            self.server.allow_reuse_address = True
            
            # Bind and activate
            self.server.server_bind()
            self.server.server_activate()
            
            host_display = self.bind_host if self.bind_host else "localhost"
            print(f"🚀 Notification server started on http://{host_display}:{self.port}")
            print(f"📁 Icons directory: {self.notification_sender.icons_dir}")
            
            # Test notify-send with Russian text
            print("\n🧪 Testing notify-send with Russian text...")
            if not self.notification_sender.test_notification():
                print("⚠️  Possible issues with notifications display")
            
            print("\n📝 Request examples (Russian text):")
            print(f'   curl "http://localhost:{self.port}/notify?title=%D0%9F%D1%80%D0%B8%D0%B2%D0%B5%D1%82&message=%D0%9C%D0%B8%D1%80"')
            print(f'   curl "http://localhost:{self.port}/test" - test page')
            print(f'   curl "http://localhost:{self.port}/" - help page')
            
            print("\n🔍 UTF-8 debugging enabled")
            print("⏳ Press Ctrl+C to stop\n")
            
            # Handle Ctrl+C
            signal.signal(signal.SIGINT, self.shutdown)
            
            self.server.serve_forever()
            
        except PermissionError:
            print(f"❌ Error: Insufficient permissions for port {self.port}")
            print("   Use port above 1024 or run with sudo:")
            print(f"   sudo python3 {sys.argv[0]} --port {self.port}")
            sys.exit(1)
        except OSError as e:
            if e.errno == 98:  # Address already in use
                print(f"❌ Error: Port {self.port} already in use")
                print("   Use different port:")
                print(f"   python3 {sys.argv[0]} --port 8080")
                sys.exit(1)
            else:
                print(f"❌ OSError: {e}")
                raise
        except Exception as e:
            print(f"❌ Unexpected error: {traceback.format_exc()}")
            sys.exit(1)
    
    def shutdown(self, signum, frame):
        """Graceful server shutdown"""
        print("\n\n🛑 Stopping server...")
        if self.server:
            self.server.shutdown()
        sys.exit(0)


def main():
    """Main function"""
    parser = argparse.ArgumentParser(
        description='HTTP server for sending notifications via notify-send with UTF-8 support',
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Usage examples:
  %(prog)s                      # Start on port 80 (requires sudo)
  %(prog)s --port 8080         # Start on port 8080
  %(prog)s --port 8080 --icons-dir ./icons  # With custom icons directory

Russian text examples:
  curl "http://localhost:8080/notify?title=%D0%9F%D1%80%D0%B8%D0%B2%D0%B5%D1%82&message=%D0%9C%D0%B8%D1%80"
  curl "http://localhost:8080/notify?title=%D0%A2%D0%B5%D1%81%D1%82&message=%D0%A0%D1%83%D1%81%D1%81%D0%BA%D0%B8%D0%B9+%D1%82%D0%B5%D0%BA%D1%81%D1%82"

Encoding guide:
  Space: %20 or +
  Cyrillic А: %D0%90
  Cyrillic а: %D0%B0
  Use encodeURIComponent() in JavaScript
        """
    )
    
    parser.add_argument('-p', '--port', type=int, default=80,
                       help='Port to listen on (default: 80)')
    parser.add_argument('--bind-host', default='',
                       help='Host to bind to (default: all interfaces)')
    parser.add_argument('-d', '--icons-dir', default='.',
                       help='Directory for icon search (default: current)')
    parser.add_argument('--test-only', action='store_true',
                       help='Only test notify-send and exit')
    
    args = parser.parse_args()
    
    # Check permissions for ports below 1024
    if args.port < 1024 and os.geteuid() != 0:
        print(f"⚠️  Warning: Port {args.port} requires administrator rights")
        print(f"   Use: sudo python3 {' '.join(sys.argv)}")
        print(f"   Or use port above 1024: python3 {sys.argv[0]} --port 8080")
        sys.exit(1)
    
    if args.test_only:
        sender = NotificationSender(args.icons_dir)
        sender.test_notification()
        return
    
    # Start server
    server = NotificationServer(
        bind_host=args.bind_host,
        port=args.port,
        icons_dir=args.icons_dir
    )
    server.start()


if __name__ == "__main__":
    main()
