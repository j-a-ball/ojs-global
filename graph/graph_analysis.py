import networkx as nx
from collections import defaultdict, Counter

def calculate_average_degrees(G):
    in_degrees = [d for n, d in G.in_degree()]
    out_degrees = [d for n, d in G.out_degree()]
    avg_in_degree = sum(in_degrees) / len(in_degrees)
    avg_out_degree = sum(out_degrees) / len(out_degrees)
    return avg_in_degree, avg_out_degree

def find_largest_fully_connected_subgraph(G):
    largest_subgraph = max(nx.strongly_connected_components(G), key=len)
    return largest_subgraph

def find_main_journals(G, metadata, largest_subgraph):
    issn_counter = Counter()
    for node in largest_subgraph:
        issns = metadata[node]['issns']
        for issn in issns:
            if issn:
                issn_counter[issn] += 1
    main_journals = issn_counter.most_common()
    return main_journals

def find_highest_degree_journals(G, metadata):
    in_degree_journals = defaultdict(list)
    out_degree_journals = defaultdict(list)
    for node, in_degree in G.in_degree():
        issns = metadata[node]['issns']
        for issn in issns:
            if issn:
                in_degree_journals[issn].append(in_degree)
    for node, out_degree in G.out_degree():
        issns = metadata[node]['issns']
        for issn in issns:
            if issn:
                out_degree_journals[issn].append(out_degree)
    highest_in_degree_journals = sorted(in_degree_journals.items(), key=lambda x: sum(x[1]) / len(x[1]), reverse=True)
    highest_out_degree_journals = sorted(out_degree_journals.items(), key=lambda x: sum(x[1]) / len(x[1]), reverse=True)
    return highest_in_degree_journals, highest_out_degree_journals

def find_highest_degree_disciplines(G, metadata):
    in_degree_disciplines = defaultdict(list)
    out_degree_disciplines = defaultdict(list)
    for node, in_degree in G.in_degree():
        disciplines = metadata[node]['disciplines']
        for discipline in disciplines:
            if discipline:
                in_degree_disciplines[discipline].append(in_degree)
    for node, out_degree in G.out_degree():
        disciplines = metadata[node]['disciplines']
        for discipline in disciplines:
            if discipline:
                out_degree_disciplines[discipline].append(out_degree)
    highest_in_degree_disciplines = sorted(in_degree_disciplines.items(), key=lambda x: sum(x[1]) / len(x[1]), reverse=True)
    highest_out_degree_disciplines = sorted(out_degree_disciplines.items(), key=lambda x: sum(x[1]) / len(x[1]), reverse=True)
    return highest_in_degree_disciplines, highest_out_degree_disciplines
