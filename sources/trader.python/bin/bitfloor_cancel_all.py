#!/usr/bin/env python
# cancels all the user's orders

import bitfloorapi

bitfloor = bitfloorapi.Client()

bitfloor.cancel_all()