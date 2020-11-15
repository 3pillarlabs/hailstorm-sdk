---
layout: post
title:  "Update Number of Threads per AWS Instance"
date:   2020-05-17 19:30:00 +0530
categories: jekyll update
---

The latest release of **Hailstorm** added the following feature:

- It is now possible to update the number of threads per agent (EC2 instance) in an AWS cluster.
  Earlier, the entire cluster needed to be disabled, and a new cluster needed to be created. This
  features saves effort and time when cluster properties need to be changed during a load test.
