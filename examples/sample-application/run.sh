#!/bin/bash

kubeclt label namespace default istio-injection=enabled
kubectl apply -f sample-application.yaml
kubectl apply -f vs.yaml