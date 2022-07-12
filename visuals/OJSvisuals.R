library("tidyverse")
library("readxl")
library("knitr")


#OJS beacon dataset, deduplicated in initial python analysis
#https://github.com/j-a-ball/ojs-global/blob/main/notebooks/JNB1_Beacon_Data_Preprocessing.ipynb
beacon <- read_csv("./data/beacon_active.csv")
nrow(beacon)

#clean the country_consolidated var; Namibia is being read as missing
beaconActive <- beacon %>% 
  select(
    context_name, 
    country_consolidated, 
    oai_url
    ) %>% 
  mutate(
    country_consolidated = if_else(str_detect(oai_url, "\\.na/"), 
                                   "NA", 
                                   country_consolidated)
  ) %>% 
  filter(
    !is.na(country_consolidated)
    ) %>% 
  rename(
    tld = country_consolidated
    )

nrow(beaconActive)
rm(beacon)


#read in the World Nank data with added top-level domains
#https://datahelpdesk.worldbank.org/knowledgebase/articles/906519-world-bank-country-and-lending-groups
wbGroups <- read_excel("./data/wb_tlds.xlsx") %>% 
  rename(
    tld = Domain,
    country = Economy,
    income_group = `Income group`
    ) %>% 
  filter(
    tld %in% beaconActive$tld
    ) %>% 
  mutate(
    income_group = if_else( #revert Venezuela's classification from
      #"Unclassified" (2021) to "Upper middle income" (2020)
      str_detect(income_group, "Unclassified"),
      "Upper middle income",
      income_group
      )
    )



#Fig. 3 -- United Nations regional groups
#https://www.un.org/dgacm/en/content/regional-groups

#create United Nations regional group vectors with country top-level domains
africa = c("DZ", "AO", "BW", "BI", "CM", "SZ", "EG", "ET", "GM", "GH", "GN", 
           "KE", "LY", "ML", "MU", "MA", "MZ", "NA", "NG", "RW", "SN", "ZA", 
           "SD", "TZ", "TN", "UG", "ZM", "ZW")

asia_pac = c("AE", "AF", "BH", "BD",  "BT", "CN", "CY", "IN", "ID", "IR", 
             "IQ", "JP", "JO", "KZ", "KR", "KW", "KG", "LB", "MY", "MN", 
             "MM", "NP", "OM", "PK", "PW", "PH", "QA", "WS", "SA", "SG", 
             "LK", "SY", "TW", "TH", "TL", "UZ", "VN", "PS", "YE")

east_euro <- c("AL", "AM", "AZ", "BY", "BA", "BG", "HR", "CZ", "EE", "GE", 
               "HU", "LV", "LT", "MD", "MK", "PL", "RO", "RU", "RS", "SK", 
               "SI", "UA")

lat_am <- c("AR", "BB", "BZ", "BO", "BR", "CL", "CO", "CR", "CU", "DO", 
            "EC", "SV", "GT", "HN", "MX", "NI", "PA", "PY", "PE", "SR", 
            "TT", "UY", "VE")

west <- c("AU", "AT", "BE", "CA", "DK", "FI", "FR", "DE", "GR", "IS", "IE", 
          "IL", "IT", "LU", "MT", "NL", "NZ", "NO", "PR", "PT", "ES", "SE", 
          "CH", "TR", "GB", "US")

#merge datasets
beaconRegions <- merge(
  beaconActive, 
  wbGroups, 
  by = "tld"
  ) %>% 
  as_tibble() %>% 
  select(
    context_name, 
    oai_url,
    tld,
    country,
    income_group
    ) %>% 
  filter(
    !str_detect(country, "Kosovo")
    ) %>% 
  mutate(
    un_region = case_when(
      tld %in% africa ~ "African States",
      tld %in% asia_pac ~ "Asia-Pacific\nStates",
      tld %in% east_euro ~ "Eastern European\nStates",
      tld %in% lat_am ~ "Latin American and\nCaribbean States",
      tld %in% west ~ "Western European\nand other States"
    )
  )

nrow(beaconRegions)
rm(beaconActive, wbGroups)

#plot
ggplot(beaconRegions,
       aes(
         y = fct_rev(fct_infreq(un_region)) #forcats package
         )
       ) +
  theme_classic() +
  theme(
    axis.title = element_text(size=20),
    axis.text = element_text(size=18),
    axis.ticks = element_blank()
    ) +
  geom_bar(
    fill = "#0072B2"
    ) +
  labs(
    x = "\nActive journals using OJS",
    y = "United Nations regional group\n"
    ) +
  geom_text(
    aes(
      label = paste0(
        scales::comma(..count..),
        " (",
        format(
          round(..count.. / 25651 * 100, digits = 1),
          nsmall = 1
          ),
        "%)")
      ),
    stat = "count",
    hjust = -0.1,
    size = 0.36 * 18
    ) +
  scale_x_continuous(
    breaks = c(0, 5000, 10000, 15000),
    labels = c("0", "5000", "10,000", "15,000"),
    limits = c(0, 19000)
    )

ggsave("./vis/OJSregions.png", dpi = 300, width = 10, height = 6)



#Fig. 2 -- World Bank country and lending groups

ggplot(beaconRegions,
       aes(
         y = fct_rev(fct_infreq(income_group)) #forcats package
         )
       ) +
  theme_classic() +
  theme(
    axis.title = element_text(size=20),
    axis.text = element_text(size=18),
    axis.ticks = element_blank()
  ) +
  geom_bar(
    fill = "#0072B2"
  ) +
  labs(
    x = "\nActive journals using OJS",
    y = "World Bank income group\n"
  ) +
  geom_text(
    aes(
      label = paste0(
        scales::comma(..count..),
        " (",
        format(
        round(..count.. / 25651 * 100, digits = 1),
        nsmall = 1
        ),
        "%)"
        )
      ),
    stat = "count",
    hjust = -0.1,
    size = 0.36 * 18
  ) +
  scale_x_continuous(
    breaks = c(0, 5000, 10000, 15000),
    labels = c("0", "5,000", "10,000", "15,000"),
    limits = c(0, 19500)
    ) +
  scale_y_discrete(
    limits = c(
      "High income", "Upper middle income", "Lower middle income", "Low income"
    )
  )

ggsave("./vis/OJSincomegroups.png", dpi = 300, width = 10, height = 6)



#Fig 1. -- Active journals using OJS in top 10 countries

beaconRegions %>% 
  add_count(country) %>% 
  arrange(desc(n)) %>%
  filter(n > 400) %>% 
  ggplot(
    aes(y = 
          fct_rev(fct_infreq(country)) #forcats package
        )
    ) +
  theme_classic() +
  theme(
    axis.title = element_text(size=20),
    axis.text = element_text(size=18),
    axis.ticks = element_blank()
    ) +
  geom_bar(
    width = 0.8,
    fill = "#0072B2"
    ) +
  labs(
    x = "\nActive journals using OJS",
    y = "Country\n"
    ) +
  geom_text(
    aes(
      label = paste0(
        scales::comma(..count..),
        " (",
        format(
          round(..count.. / 25651 * 100, digits = 1),
          nsmall = 1
        ),
        "%)"
        )
      ),
    stat = "count",
    hjust = -0.08,
    size = 0.36 * 18
    ) +
  scale_x_continuous(
    breaks = c(0, 2500, 5000, 7500, 10000, 12500),
    labels = c("0", "2,500", "5,000", "7,500", "10,000", "12,500"),
    limits = c(0, 15550)
    )

ggsave("./vis/OJScountries.png", dpi = 300, width = 10, height = 6)



#Fig. 4 -- Top 10 primary languages of publishing for journals using OJS

ojsLangs <- read_csv("./data/OJS_languages_v3.csv")

ojsLangs %>% 
  add_count(language) %>% 
  arrange(desc(n)) %>%
  filter(n > 80) %>% 
  ggplot(
    aes(
      y = fct_rev(fct_infreq(language))
      )
    ) +
  theme_classic() +
  theme(
    axis.title = element_text(size=20),
    axis.text = element_text(size=18),
    axis.ticks = element_blank()
  ) +
  geom_bar(
    width = 0.8,
    fill = "#0072B2"
  ) +
  labs(
    x = "\nActive journals using OJS",
    y = "Language\n"
  ) +
  geom_text(
    aes(
      label = paste0(
        scales::comma(..count..),
        " (",
        format(
          round(..count.. / 22561 * 100, digits = 1),
          nsmall = 1
        ),
        "%)"
        )
    ),
    stat = "count",
    hjust = -0.08,
    size = 0.36 * 18
  ) +
  scale_x_continuous(
    breaks = c(0, 2500, 5000, 7500, 10000, 12500),
    labels = c("0", "2,500", "5,000", "7,500", "10,000", "12,500"),
    limits = c(0, 15000)
    )
  

ggsave("./vis/OJSlanguages.png", dpi = 300, width = 10, height = 6)



#Fig 5. -- Multilingual publishing among journals using OJS
#https://github.com/j-a-ball/ojs-global/blob/main/notebooks/JNB3_Languages.ipynb
mono <- rep("Mono-* (1 language)", 10165)
bi <- rep("Bi-* (2 languages)", 9254)
multi <- rep("Multi-* (3+ languages", 2963)


ojsMulti <- tibble(
  multiple = c(mono, bi, multi),
  ) %>% 
  add_count(multiple) %>% 
  arrange(desc(n))

ggplot(ojsMulti,
       aes(
         y = fct_rev(fct_infreq(multiple))
         )
       ) +
  theme_classic() +
  theme(
    axis.title = element_text(size=20),
    axis.text = element_text(size=18),
    axis.ticks = element_blank()
  ) +
  geom_bar(
    fill = "#0072B2"
  ) +
  labs(
    x = "\nActive journals using OJS",
    y = "*-lingual journals\n"
  ) +
  geom_text(
    aes(
      label = paste0(
        scales::comma(..count..),
        " (",
        format(
          round(..count.. / 22382 * 100, digits = 1),
          nsmall = 1
        ),
        "%)"
        )
    ),
    stat = "count",
    hjust = -0.08,
    size = 0.36 * 18
  ) +
  scale_x_continuous(
    breaks = c(0, 10000),
    labels = c("0", "10,000"),
    limits = c(0, 14000)
  )

ggsave("./vis/OJSmultilingual.png", dpi = 300, width = 10, height = 6)



#Fig. 6 -- Journals using OJS by field of study
#figures below determined using Weber et al.'s (2020) field of study classifier
#https://github.com/j-a-ball/ojs-global/blob/main/notebooks/JNB4_Disciplines_and_Fields_of_Study.ipynb
math <- rep("Mathematical Sciences", 136)
phys <- rep("Physical Sciences", 67)
chem <- rep("Chemical Sciences", 133)
earth <- rep("Earth and Environmental Sciences", 394)
bio <- rep("Biological Sciences", 762)
ag <- rep("Agricultural and Veterinary Sciences", 284)
cs <- rep("Information and Computing Sciences", 966)
entech <- rep("Engineering and Technology", 2608)
med <- rep("Medical and Health Sciences", 3374)
design <- rep("Built Environment and Design", 334)
ed <- rep("Education", 2537)
econ <-  rep("Economics", 699)
mgmt <- rep("Commerce, Management, Tourism and Services", 2606)
soc <- rep("Studies in Human Society", 3180)
psych <- rep("Psychology and Cognitive Sciences", 507)
law <- rep("Law and Legal Studies", 811)
arts <- rep("Studies in Creative Arts and Writing", 157)
comm <- rep("Language, Communication and Culture", 2100)
hist <- rep("History and Archaeology", 407)
phil <- rep("Philosophy and Religious Studies", 442)

ojsFOS <- tibble(
  fos = c(math, phys, chem, earth, bio, ag, cs, entech, med, design,
          ed, econ, mgmt, soc, psych, law, arts, comm, hist, phil)
)

ggplot(ojsFOS,
       aes(
         y = fct_rev(fct_infreq(fos))
         )
       ) +
  theme_classic() +
  theme(
    axis.title = element_text(size=20),
    axis.text = element_text(size=16),
    axis.ticks = element_blank()
  ) +
  geom_bar(
    width = 0.8,
    fill = "#0072B2"
  ) +
  labs(
    x = "\nActive journals using OJS",
    y = "Discipline\n"
  ) +
  geom_text(
    aes(
      label = paste0(
        scales::comma(..count..),
        " (",
        format(
          round(..count.. / 22504 * 100, digits = 1),
          nsmall = 1
        ),
        "%)"
        )
    ),
    stat = "count",
    hjust = -0.08,
    size = 0.36 * 16
  ) +
  scale_x_continuous(
    breaks = c(0, 1000, 2000, 3000),
    labels = c("0", "1,000", "2,000", "3,000"),
    limits = c(0, 5500)
  )

ggsave("./vis/OJSdisciplines.png", dpi = 300, width = 10, height = 8)



#Fig 7. -- Journals using OJS by field of study division

socsci<- rep("Social Sciences", 10340)
stem <- rep("STEM", 9058)
hum <- rep("Humanities", 3106)

ojsDiv <- tibble(
  div = c(socsci, stem, hum)
  ) %>% 
  add_count(div) %>% 
  arrange(desc(n))

ggplot(ojsDiv,
       aes(
         y = fct_rev(fct_infreq(div))
         )
       ) +
  theme_classic() +
  theme(
    axis.title = element_text(size=20),
    axis.text = element_text(size=18),
    axis.ticks = element_blank()
  ) +
  geom_bar(
    fill = "#0072B2"
  ) +
  labs(
    x = "\nActive journals using OJS",
    y = "Division\n"
  ) +
  geom_text(
    aes(
      label = paste0(
        scales::comma(..count..),
        " (",
        format(
          round(..count.. / 22504 * 100, digits = 1),
          nsmall = 1
        ),
        "%)"
        )
    ),
    stat = "count",
    hjust = -0.08,
    size = 0.36 * 18
  ) +
  scale_x_continuous(
    breaks = c(0, 10000),
    labels = c("0", "10,000"),
    limits = c(0, 14000)
  )

ggsave("./vis/OJSdivisions.png", dpi = 300, width = 10, height = 6)