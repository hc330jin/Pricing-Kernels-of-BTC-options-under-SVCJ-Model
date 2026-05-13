import csv
import os
import numpy as np
import pandas as pd
import matplotlib.pyplot as plt
import scipy.stats as stats
from statsmodels.graphics.tsaplots import plot_acf, plot_pacf
from statsmodels.tsa.stattools import acf, pacf
import seaborn as sns

BASE_DIR = os.path.dirname(os.path.abspath(__file__))

def Input(s, i, N):
    folder = f'SVCJ_{N}_estimate_{s}_{i}'
    folder_path = os.path.join(BASE_DIR, folder)

    file_path = os.path.join(folder_path, 'trace.csv')
    df = pd.read_csv(file_path)

    print(df.head())
    print(df.columns)

    V = df["V"].to_numpy()
    J = df["J"].to_numpy()

    file_path = os.path.join(folder_path, 'return.csv')
    df = pd.read_csv(file_path, header=None)
    Y = df.iloc[:, 1].to_numpy()

    return V, J, Y

# ======== Here to modify iterations of MCMC ========
N = 100000
# ======== Here to modify iterations of MCMC ========

jumpProb = np.array([])
Return = np.array([])
volatility = np.array([])

# ======== Here to modify which asset ========
assets=['BITCOIN']# ['SPX','DTTF','EUS','HSI','BITCOIN','GOLD','USD']
# ======== Here to modify which asset ========
for s in assets:
    for i in range(1, 2, 1):
        V, J, Y=Input(s, i, N)
        jumpProb=np.concatenate((jumpProb,J), 0)
        Return=np.concatenate((Return,Y), 0)
        volatility=np.concatenate((volatility, V), 0)
print(jumpProb)
index=np.array([i for i in range(1, len(jumpProb)+1)])

fig, ax = plt.subplots(3, 1, figsize=(12,8))

# Jump probability
ax[0].plot(index, jumpProb, color='skyblue')
ax[0].set_ylabel('Jump Probability')
ax[0].set_title(f'SVCJ Estimated Results for {s}')

# Return
ax[1].plot(index, Return[0:len(index)], color='gold')
ax[1].set_ylabel('Return(%)')

# Volatility
ax[2].plot(index, volatility, color='red')
ax[2].set_ylabel('Volatility(%)')
ax[2].set_xlabel('Time Index')

plt.tight_layout()

save_path = os.path.join(BASE_DIR, 'Figures')

os.makedirs(save_path, exist_ok=True)

filename = f'SVCJ_{s}_result.png'

plt.savefig(
    os.path.join(save_path, filename),
    dpi=300,
    bbox_inches='tight'
)

plt.show()