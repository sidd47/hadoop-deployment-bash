#!/bin/bash
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
# http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#
# Copyright Clairvoyant 2015

#for X in `awk -F@ '{print $2}' hosts-QA `;do
#  Y=`echo $X|sed -e 's|\.|-|g'`
#  Z=`host "ip-${Y}.us-west-2.compute.internal."`
#  echo "$Z" | awk "{print \$4,\$1,\"ip-$Y\"}"
#done >hostlist

HOSTLIST=$1
if [ -z $HOSTLIST ]; then
  echo "ERROR: Missing hostlist file."
  exit 1
fi
#sed -i -e '/^[0-9]/d' /etc/hosts
cat $HOSTLIST >>/etc/hosts

