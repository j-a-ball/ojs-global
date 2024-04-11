import os
import re
import backoff
import requests
import pandas as pd
from concurrent.futures import ThreadPoolExecutor, as_completed
from tqdm import tqdm
from requests.adapters import HTTPAdapter
from requests.packages.urllib3.util.retry import Retry
from urllib3.exceptions import MaxRetryError
import random
import time
import warnings

# Silence warnings due to using verify=False
warnings.filterwarnings("ignore", category=requests.packages.urllib3.exceptions.InsecureRequestWarning)

# Params
DATA_DIR = "data"
BEACON_FILE = "beacon.csv"
WEBPAGE_DIR = "webpages"
UPDATED_BEACON_FILE = "beacon_issn_match.csv"
MAX_WORKERS = 8 
TIMEOUT = 10 
MAX_RETRIES = 2 

def extract_journal_url(row):
    oai_url = str(row["oai_url"])
    set_spec = str(row["set_spec"])
    return re.sub(r"index/oai$|oai$", "", oai_url) + set_spec

@backoff.on_exception(backoff.expo, (requests.exceptions.RequestException, MaxRetryError), max_tries=MAX_RETRIES)
def scrape_webpage(url):
    retry_strategy = Retry(
        total=MAX_RETRIES,
        status_forcelist=[429, 500, 502, 503, 504],
        allowed_methods=["HEAD", "GET", "OPTIONS"]
    )
    adapter = HTTPAdapter(max_retries=retry_strategy)
    session = requests.Session()
    session.mount("https://", adapter)
    session.mount("http://", adapter)

    headers = {
        "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/93.0.4577.82 Safari/537.36"
    }

    try:
        response = session.get(url, timeout=TIMEOUT, headers=headers, verify=False)
        response.raise_for_status()
        return response.text
    except requests.exceptions.RequestException as e:
        print(f"Error scraping {url}: {e}")
        return None

def check_issn_match(html, issns):
    if html is None:
        return False
    for issn in issns:
        if re.search(rf"{issn}", html):
            return True
    return False

def check_ojs_match(html):
    if html is None:
        return False
    if re.search(r"Open Journal Systems", html):
        return True
    return False

def process_row(row):
    url = row["journal_url"]
    set_spec = str(row["set_spec"])
    issns = str(row["issn"]).split() if row["issn"] else []
    file_path = os.path.join(DATA_DIR, WEBPAGE_DIR, f"{set_spec}.html")

    if os.path.exists(file_path):
        with open(file_path, "r", encoding="utf-8") as file:
            html = file.read()
    else:
        html = scrape_webpage(url)
        if html is not None:
            with open(file_path, "w", encoding="utf-8") as file:
                file.write(html)

    issn_webpage_match = check_issn_match(html, issns)
    ojs_in_html = check_ojs_match(html)
    scrape_success = html is not None
    return issn_webpage_match, ojs_in_html, scrape_success

def main():
    # Read the beacon.csv file
    beacon_df = pd.read_csv(os.path.join(DATA_DIR, BEACON_FILE))

    # Extract journal URLs
    beacon_df["journal_url"] = beacon_df.apply(extract_journal_url, axis=1)

    # Create the webpage directory if it doesn't exist
    os.makedirs(os.path.join(DATA_DIR, WEBPAGE_DIR), exist_ok=True)

    # Shuffle the rows of the DataFrame (so requests to different servers are distributed evenly)
    beacon_df = beacon_df.sample(frac=1).reset_index(drop=True)

    # Parallelize the processing of rows
    with ThreadPoolExecutor(max_workers=MAX_WORKERS) as executor:
        futures = []
        for _, row in beacon_df.iterrows():
            future = executor.submit(process_row, row)
            futures.append(future)

        results_issn_match = []
        results_scrape_success = []
        results_ojs_in_html = []
        with tqdm(total=len(futures), desc="Processing rows") as progress_bar:
            for future in as_completed(futures):
                issn_webpage_match, ojs_in_html, scrape_success = future.result()
                results_issn_match.append(issn_webpage_match)
                results_ojs_in_html.append(ojs_in_html)
                results_scrape_success.append(scrape_success)
                progress_bar.update(1)
                
                # Add a random delay between requests
                time.sleep(random.uniform(0.1, 0.5))

    # Add the issn_webpage_match, ojs_in_html, and scrape_success columns
    beacon_df["issn_webpage_match"] = results_issn_match
    beacon_df["ojs_in_html"] = results_ojs_in_html
    beacon_df["scrape_success"] = results_scrape_success

    # Save the updated DataFrame to a new CSV file
    beacon_df.to_csv(os.path.join(DATA_DIR, UPDATED_BEACON_FILE), index=False)


if __name__ == "__main__":
    main()