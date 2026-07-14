from slowapi import Limiter
from slowapi.util import get_remote_address

# Defined here (not in main.py) so any router can import it
# without creating a circular import with main.py
limiter = Limiter(key_func=get_remote_address)
