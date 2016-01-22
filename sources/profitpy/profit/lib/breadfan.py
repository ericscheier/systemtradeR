#!/usr/bin/env python
# -*- coding: utf-8 -*-

# Copyright 2007 Troy Melhase
# Distributed under the terms of the GNU General Public License v2
# Author: Troy Melhase <troy@gci.net>


ffnet = NN = inf = None
try:
    from ffnet import ffnet, mlgraph, loadnet, savenet, savenet, loadnet
    from scipy import inf
except (ImportError, ):
    from profit.lib.bpnn import NN


class NeuralNetwork(object):
    def __init__(self):
        self.network = None


class SimpleNeuralNetwork(NeuralNetwork):
    train_meta = {
        'backprop':{
            'name':'Backprop',
            'desc':'Simple backprop.',
            'method':'train',
            'params':{
                'iterations':
                    {'type':int, 'default':1000, 'help':'Iterations'},
                'N':
                    {'type':float, 'default':0.5, 'help':'Learning rate'},
                'M':
                    {'type':float, 'default':0.1, 'help':'momentum factor'},
                }
            },
        }

    def __init__(self):
        self.network = NN(ni=3, nh=10, no=1)

    def save(self, *args):
        pass

    def load(self, *args):
        pass

    def inputs(self):
        return self.network.ni - 1

    def hidden(self):
        return self.network.nh

    def outno(self):
        return self.network.no

    @property
    def trained(self):
        return 'backprop' if bool(self.network.ao) else ''


class FfnetNeuralNetwork(NeuralNetwork):
    train_meta = {
        'momentum':{
            'name':'Backprop with momentum',
            'desc':'Simple backpropagation training with momentum.',
            'method':'train_momentum',
            'params':{
                'eta':
                    {'type':float, 'default':0.2,
                     'help':'descent scaling parameter'},
                'momentum':
                    {'type':float, 'default':0.8,
                     'help':'momentum coefficient'},
                'maxiter':
                    {'type':int, 'default':10000,
                     'help':'the maximum number of iterations'},
                'disp':
                    {'type':int, 'default':0,
                    'help':'print convergence message if non-zero'},
            }
        },

        'rprop':{
            'name':'Rprop',
            'desc':'Rprop training algorithm.',
            'method':'train_rprop',
            'params':{
                'a':
                    {'type':float, 'default':1.2,
                     'help':'training step increasing parameter'},
                'b':
                    {'type':float, 'default':0.5,
                     'help':'training step decreasing parameter'},
                'mimin':
                    {'type':float, 'default':0.000001,
                     'help':'minimum training step'},
                'mimax':
                    {'type':float, 'default':50.0,
                     'help':'maximum training step'},
                'xmi':
                    {'type':float, 'default':0.1,
                     'help':'initial weight scalar; vector not supported'},
                'maxiter':
                    {'type':int, 'default':10000,
                     'help':'the maximum number of iterations'},
                'disp':
                    {'type':int, 'default':0,
                     'help':'print convergence message if non-zero'},
            }
        },


        'genetic':{
            'name':'Genetic',
            'desc':'Global weights optimization with genetic algorithm.',
            'method':'train_genetic',
            'params':{
                'lower':
                    {'type':float, 'default':-25.0,
                     'help':'lower bound of weights values'},
                'upper':
                    {'type':float, 'default':25.0,
                     'help':'upper bound of weights values'},
                'individuals':
                    {'type':int, 'default':20,
                     'help':'number of individuals in a population'},
                'generations':
                    {'type':int, 'default':500,
                     'help':'number of generations over which solution is to evolve'},
                'crossover':
                    {'type':float, 'default':0.85,
                     'help':'crossover probability; must be  <= 1.0'},
                'mutation':
                    {'type':int, 'default':2,
                     'help':'', 'choices':[(1, 'one-point mutation, fixed rate'),
                                           (2, 'one-point, adjustable rate based on fitness'),
                                           (3, 'one-point, adjustable rate based on distance'),
                                           (4, 'one-point+creep, fixed rate'),
                                           (5, 'one-point+creep, adjustable rate based on fitness'),
                                           (6, 'one-point+creep, adjustable rate based on distance'),
                                          ]},
                'initrate':
                    {'type':float, 'default':0.005,
                     'help':'initial mutation rate; should be small; mutation rate is the probability that any one gene locus will mutate in  any one generation.'},
                'minrate':
                    {'type':float, 'default':0.0005,
                     'help':'minimum mutation rate; must be >= 0.0'},
                'maxrate':
                    {'type':float, 'default':0.25, 'min':0, 'max':1.0,
                     'help':'maximum mutation rate; must be <= 1.0'},
                'fitnessdiff':
                    {'type':float, 'default':1.0, 'min':0, 'max':1.0, 'min_special':'none',
                     'help':'relative fitness differential'},
                 'reproduction':
                    {'type':int, 'default':3,
                     'help':'reproduction plan', 'choices':[(1, 'Full generational replacement'),
                                                            (2, 'Steady-state-replace-random'),
                                                            (3, 'Steady-state-replace-worst')]},
                 'elitism':
                    {'type':int, 'default':0, 'checkbox':True,
                     'help':'elitism flag; (Applies only to reproduction plans 1 and 2)'},
                 'verbosity':
                    {'type':int, 'default':0,
                     'help':'printed output', 'choices':[(0, 'None'),
                                                         (1, 'Minimal'),
                                                         (2, 'Verbose')]},
            }
        },


        'cg':{
            'name':'Conjugate Gradient',
            'desc':'nonlinear conjugate gradient algorithm of Polak and Ribiere.',
            'method':'train_cg',
            'params':{
                 'gtol':
                    {'type':float, 'default':0.00001,
                     'help':'stop when norm of gradient is less than gtol'},
                 'norm':
                    {'type':float, 'default':inf,
                     'help':'order of vector norm to use', 'min_special':'inf', },
                 'maxiter':
                    {'type':int, 'default':10000,
                     'help':'the maximum number of iterations'},
                'disp':
                    {'type':int, 'default':1,
                    'help':'print convergence message if non-zero'},
            },
        },
        ## add support for train_bfgs and train_tnc here
    }
    def __init__(self, con=(2,2,1)):
        self.network = ffnet(mlgraph(con))

    def save(self, filename):
        savenet(self.network, filename)

    def load(self, filename):
        self.network = loadnet(filename)

    def inputs(self):
        return len(self.network.inno)

    def hidden(self):
        return len(self.network.hidno)

    def outno(self):
        return len(self.network.outno)

    @property
    def trained(self):
        return self.network.trained


def make_network():
    if ffnet:
        return FfnetNeuralNetwork()
    #elif ...
    else:
        return SimpleNeuralNetwork()
