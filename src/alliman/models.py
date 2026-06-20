"""Pydantic models for alliman's structured output (family contract)."""

from __future__ import annotations

from pydantic import BaseModel


class DoctorCheck(BaseModel):
    """A single install-verification check and its outcome."""

    name: str
    ok: bool
    detail: str = ""


class DoctorReport(BaseModel):
    """The aggregate of all install-verification checks."""

    checks: list[DoctorCheck]

    @property
    def ok(self) -> bool:
        return all(c.ok for c in self.checks)

    def to_dict(self) -> dict:
        return self.model_dump()
