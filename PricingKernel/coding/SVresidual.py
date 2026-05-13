import csv
import os
import numpy as np
import pandas as pd
import matplotlib.pyplot as plt
import scipy.stats as stats
from statsmodels.graphics.tsaplots import plot_acf, plot_pacf
from statsmodels.tsa.stattools import acf, pacf
import seaborn as sns

def Input(s, i, N):
    file_path=f'SV_{N}estimate_{s}_{i}/trace.csv'
    df=pd.read_csv(file_path)
    V=df["V"].to_numpy()

    file_path=f'SV_{N}estimate_{s}_{i}/return.csv'
    df=pd.read_csv(file_path, header=None)
    Y=df.iloc[:,1].to_numpy()

    file_path=f'SV_{N}estimate_{s}_{i}/sum.csv'
    df=pd.read_csv(file_path)
    mu=df["mu"].to_numpy()
    
    file_path=f'SV_{N}estimate_{s}_{i}/parameters.csv'
    df=pd.read_csv(file_path)
    mu_dist=df["mu"].to_numpy()
    alpha_dist=df["alpha"].to_numpy()
    beta_dist=df["beta"].to_numpy()
    sig2V_dist=df["sigma2_v"].to_numpy()
    rho_dist=df["rho"].to_numpy()

    return V, Y, mu, mu_dist, alpha_dist, beta_dist, sig2V_dist, rho_dist

def Residuals(V, Y, mu):
    Resid=(Y-mu)/np.sqrt(V)
    return Resid

def plotQQ(Resid):
    #print(Resid, type(Resid), np.shape(Resid))
    stats.probplot(Resid, dist="norm", plot=plt)
    plt.title("SV Model Residuals QQ-Plot")
    plt.show()

def distribution(data, dist, loc, scale):
    if dist=='normal':
        fig, ax=plt.subplots(1, 2, figsize=(12, 4))
        sample=np.random.normal(loc=loc, scale=scale, size=1000)
        sns.histplot(sample, kde=True, ax=ax[0], color='skyblue')
        sns.histplot(data, kde=True, ax=ax[1], color='salmon')
    elif dist=='beta':
        fig, ax=plt.subplots(1, 2, figsize=(12, 4))
        sample=stats.beta.rvs(a=loc, b=scale, size=1000)
        sns.histplot(sample, kde=True, ax=ax[0], color='skyblue')
        sns.histplot(data, kde=True, ax=ax[1], color='salmon')
    elif dist=='mvn':
        sample=np.random.multivariate_normal(loc, scale, size=1000)
        sns.jointplot(x=sample[:, 0], y=sample[:, 1], kind='kde', cmap='Blues', fill=True)
        
        sns.jointplot(x=data[0, :], y=data[1, :], kind='kde', cmap='Greens', fill=True)
        '''fig, axes = plt.subplots(2, 2, figsize=(12, 8))

        # --- Alpha 的圖 ---
        sns.kdeplot(data[0, :], ax=axes[0, 0], fill=True, color="skyblue")
        axes[0, 0].set_title(f'Alpha Posterior Density (Mean: {np.mean(data[0, :]):.4f})')

        axes[0, 1].plot(data[0, :], color="skyblue", linewidth=0.5)
        axes[0, 1].set_title('Alpha Trace Plot (Should be a hairy caterpillar)')

        # --- Beta (Phi) 的圖 ---
        sns.kdeplot(data[1, :], ax=axes[1, 0], fill=True, color="salmon")
        axes[1, 0].set_title(f'Beta Posterior Density (Mean: {np.mean(data[1, :]):.4f})')

        axes[1, 1].plot(data[1, :], color="salmon", linewidth=0.5)
        axes[1, 1].set_title('Beta Trace Plot (Should be a hairy caterpillar)')

        plt.tight_layout()'''
        
    elif dist=='invG':
        fig, ax=plt.subplots(1, 2, figsize=(12, 4))
        sample=stats.invgamma.rvs(a=loc, scale=scale, size=1000)
        sns.histplot(sample, kde=True, ax=ax[0], color='skyblue')
        sns.histplot(data, kde=True, ax=ax[1], color='salmon')
    
    
    plt.show()

    return

assets=['GC']#, 'IXIC', 'IEMG', 'GC', 'SI', 'CL', 'BCOM', 'BTC']
N=10000
for s in assets:
    for i in range(2001, 3000, 999):
        V, Y, mu, mu_dist, alpha_dist, beta_dist, sig2V_dist, rho_dist=Input(s, i, N)
        distribution(mu_dist, 'normal', 0, 25)
        #distribution(np.array([alpha_dist, beta_dist]), 'mvn',[0, 0], [[1, 0], [0, 1]])
        distribution(sig2V_dist, 'invG', 2.5, 0.1)
        Resid=Residuals(V, Y, mu)
        plotQQ(Resid)