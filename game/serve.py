#!/usr/bin/env python3
"""Mały lokalny serwer dla gry Czarny Rynek (bez cache). Użycie: python3 serve.py [port] [--no-browser]"""
import http.server, socketserver, sys, os, webbrowser, threading

os.chdir(os.path.dirname(os.path.abspath(__file__)))
args = [a for a in sys.argv[1:] if not a.startswith('--')]
PORT = int(args[0]) if args else 8765


AUDIO_EXT = ('.mp3', '.m4a', '.ogg', '.wav', '.aac', '.flac')


class Handler(http.server.SimpleHTTPRequestHandler):
    def do_GET(self):
        # lista własnych utworów z folderu „muzyka/” (grają w klubie i w jego pobliżu)
        if self.path.split('?')[0] == '/api/music':
            import json, urllib.parse
            files = []
            if os.path.isdir('muzyka'):
                files = sorted('muzyka/' + urllib.parse.quote(f) for f in os.listdir('muzyka') if f.lower().endswith(AUDIO_EXT))
            body = json.dumps(files).encode('utf-8')
            self.send_response(200)
            self.send_header('Content-Type', 'application/json; charset=utf-8')
            self.send_header('Content-Length', str(len(body)))
            self.end_headers()
            self.wfile.write(body)
            return
        super().do_GET()

    def end_headers(self):
        self.send_header('Cache-Control', 'no-store')
        super().end_headers()

    def log_message(self, *a):
        pass


class Server(socketserver.TCPServer):
    allow_reuse_address = True


with Server(('127.0.0.1', PORT), Handler) as httpd:
    url = f'http://localhost:{PORT}/'
    print(f'Czarny Rynek działa na {url}  (Ctrl+C aby zakończyć)')
    if '--no-browser' not in sys.argv:
        threading.Timer(0.6, lambda: webbrowser.open(url)).start()
    try:
        httpd.serve_forever()
    except KeyboardInterrupt:
        print('\nDo zobaczenia.')
