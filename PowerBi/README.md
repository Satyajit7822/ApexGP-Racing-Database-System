# 🏎️ ApexGP Racing — Power BI Dashboard

## 📊 Overview

The **ApexGP Racing Power BI Dashboard** is the analytics and data visualization layer of the **ApexGP Racing Database System**.

The dashboard uses racing data stored in **MySQL** and transforms it into interactive visualizations for analyzing championship performance, driver performance, teams, races, circuits, and driver nationalities.

---

## 📑 Dashboard

The Power BI report currently contains **two interactive dashboard pages**.

### 🏆 Page 1 — Championship Overview

The Championship Overview provides a high-level view of the ApexGP racing championship.

#### Key Performance Indicators

- 👥 **Total Teams**
- 🏎️ **Total Drivers**
- 🏁 **Total Races**
- 🌍 **Total Circuits**
- ⏱️ **Average Lap Time**
- 📊 **Average Finishing Position**

#### Visualizations

- **Drivers by Team**
- **Team Championships**
- **Driver Nationality Distribution**
- **Races by Season**

#### Interactive Slicers

- 📅 **Season**
- 🏎️ **Team**
- 🏁 **Circuit**

![Championship Overview](Dashboard_Page1.png)

---

### 🏎️ Page 2 — Driver Performance

The Driver Performance dashboard provides detailed analysis of individual driver performance.

#### Key Performance Indicators

- 🏁 **Fastest Lap**
- ⏱️ **Average Lap Time**
- 📊 **Average Finish Position**
- 🏆 **Best Finish Position**

#### Visualizations

- **Top 10 Fastest Drivers**
- **Drivers by Nationality**
- **Top 10 Drivers by Average Finish**
- **Driver Performance Details**

#### Interactive Slicers

- 📅 **Season**
- 🏎️ **Team**
- 🌍 **Nationality**

![Driver Performance](Dashboard_Page2.png)

---

## 🗄️ Data Source

The dashboard is built using the **ApexGP Racing Database System** developed in MySQL.

### Database Tables

```text
teams
drivers
circuits
races
laptimes
