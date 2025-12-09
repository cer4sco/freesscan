"""Pattern definitions for secret scanning"""

from .aws import AWS_PATTERNS
from .generic import GENERIC_PATTERNS
from .cloud import CLOUD_PATTERNS

__all__ = ['AWS_PATTERNS', 'GENERIC_PATTERNS', 'CLOUD_PATTERNS']
