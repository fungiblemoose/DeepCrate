"""Background worker utilities for Qt."""

from __future__ import annotations

import traceback
from typing import Any, Callable

from PySide6.QtCore import QObject, QRunnable, Signal


class WorkerSignals(QObject):
    """Signals for worker task lifecycle."""

    finished = Signal(object)
    error = Signal(str)
    progress = Signal(object)


class Worker(QRunnable):
    """Run a callable in Qt's global thread pool."""

    def __init__(self, fn: Callable[..., Any], *args: Any, **kwargs: Any) -> None:
        super().__init__()
        self.fn = fn
        self.args = args
        self.kwargs = kwargs
        self.signals = WorkerSignals()

    def run(self) -> None:
        try:
            result = self.fn(*self.args, progress_cb=self.signals.progress.emit, **self.kwargs)
        except Exception:
            self.signals.error.emit(traceback.format_exc())
            return

        self.signals.finished.emit(result)
