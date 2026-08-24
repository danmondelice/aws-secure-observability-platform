"""Gunicorn defaults appropriate for a small EC2 lab instance."""

import os


bind = os.getenv("APP_BIND", "127.0.0.1:8000")
workers = int(os.getenv("WEB_CONCURRENCY", "2"))
threads = int(os.getenv("WEB_THREADS", "2"))
timeout = 30
graceful_timeout = 30
keepalive = 5
accesslog = "-"
errorlog = "-"
capture_output = True
