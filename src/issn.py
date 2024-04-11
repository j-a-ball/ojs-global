# MIT License
#
# Copyright (c) 2023 Technische Informationsbibliothek (TIB)
#
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:

# The above copyright notice and this permission notice shall be included in all
# copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
# SOFTWARE.
# https://github.com/TIB-Digital-Preservation/tib-lza-keepers-query/blob/main/keepers_query_func.py


import json
import requests
from requests.adapters import HTTPAdapter
from urllib3.util import Retry
from json.decoder import JSONDecodeError


def get_json_from_portal(issn):

    """Returns a dictionary with the complete JSON data for a given ISSN."""

    # using a requests session to implement a retry strategy. independent of the query
    # interval (0 to 2 seconds) our requests time out in an irregular pattern.
    session = requests.Session()
    retries = Retry(total=6, backoff_factor=2, status_forcelist=[429, 500, 502, 503, 504])
    adapter = HTTPAdapter(max_retries=retries)
    session.mount("https://", adapter)
    session.mount("http://", adapter)

    response = session.get(f'https://portal.issn.org/resource/ISSN/{issn}?format=json')

    # cases we need to handle:
    #     * status code 403: forbidden. this could be a temporary ban when we looked
    #       suspicious somehow. stopping the script is nice behavior. code 429 should be
    #       handled appropriately by urllib3 without our intervention.
    #     * status code 200 / response ok:
    #         - the given ISSN does not exist: no JSON response, redirect to user input
    #           (response history will say 302, page says ISSN not valid)
    #         - successful JSON response, existing ISSN (response history empty)
    #     * other status codes. those should simply get logged.

    # stop here, if we appear to be banned
    if response.status_code == 403:                                 # int, no quotes
        logger.error('Got 403 (forbidden) from ISSN Portal. Stopping query now.')
        return '403 abort now', None

    if response.ok:
        try:                                                        # expected case
            response_as_dict = response.json()
            return response_as_dict, response.text
        except JSONDecodeError:
            if 'The requested numbers do not correspond to valid ISSNs' in response.text:
                return 'invalid ISSN', None
            else:
                return 'JSON decode error', None
    else:
        return str(response.status_code), None


# Copyright (C) 2010-2015 Arthur de Jong
#
# This library is free software; you can redistribute it and/or
# modify it under the terms of the GNU Lesser General Public
# License as published by the Free Software Foundation; either
# version 2.1 of the License, or (at your option) any later version.
#
# This library is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
# Lesser General Public License for more details.
#
# You should have received a copy of the GNU Lesser General Public
# License along with this library; if not, write to the Free Software
# Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA
# 02110-1301 USA

"""ISSN (International Standard Serial Number).

The ISSN (International Standard Serial Number) is the standard code to
identify periodical publications (e.g. magazines).

An ISSN has 8 digits and is formatted in two pairs of 4 digits separated by a
hyphen. The last digit is a check digit and may be 0-9 or X (similar to
ISBN-10).

More information:

* https://en.wikipedia.org/wiki/International_Standard_Serial_Number
* https://www.issn.org/

>>> validate('0024-9319')
'00249319'
>>> validate('0032147X')
Traceback (most recent call last):
    ...
InvalidChecksum: ...
>>> validate('003214712')
Traceback (most recent call last):
    ...
InvalidLength: ...
>>> compact('0032-1478')
'00321478'
>>> format('00249319')
'0024-9319'
>>> to_ean('0264-3596')
'9770264359008'
"""


from stdnum import ean
from stdnum.exceptions import *
from stdnum.util import clean, isdigits


def compact(number):
    """Convert the ISSN to the minimal representation. This strips the number
    of any valid ISSN separators and removes surrounding whitespace."""
    return clean(number, ' -').strip().upper()


def calc_check_digit(number):
    """Calculate the ISSN check digit for 8-digit numbers. The number passed
    should not have the check digit included."""
    check = (11 - sum((8 - i) * int(n)
                      for i, n in enumerate(number))) % 11
    return "X" if check == 10 else str(check)


def validate(number):
    """Check if the number is a valid ISSN. This checks the length and
    whether the check digit is correct."""
    number = compact(number)
    if not isdigits(number[:-1]):
        raise InvalidFormat()
    if len(number) != 8:
        raise InvalidLength()
    if calc_check_digit(number[:-1]) != number[-1]:
        raise InvalidChecksum()
    return number


def is_valid(number):
    """Check if the number provided is a valid ISSN."""
    try:
        return bool(validate(number))
    except ValidationError:
        return False


def format(number):
    """Reformat the number to the standard presentation format."""
    number = compact(number)
    return number[:4] + '-' + number[4:]


def to_ean(number, issue_code='00'):
    """Convert the number to EAN-13 format."""
    number = "977" + validate(number)[:-1] + issue_code
    return number + ean.calc_check_digit(number)


if __name__ == "__main__":
    
    from collections import defaultdict
    from tqdm import tqdm
    import logging

    logger = logging.getLogger(__name__)
    issns = None #load issns here
    issn2json = defaultdict(dict)
    for issn in tqdm(issns):
        issn2json[issn], _ = get_json_from_portal(issn)
    with open("data/issn2json.json", "w") as outfile:
        json.dump(issn2json, outfile)
