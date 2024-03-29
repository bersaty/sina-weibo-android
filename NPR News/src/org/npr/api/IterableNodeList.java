// Copyright 2009 Google Inc.
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

package org.npr.api;

import org.w3c.dom.Node;
import org.w3c.dom.NodeList;

import java.util.Iterator;

public class IterableNodeList implements Iterable<Node>, Iterator<Node> {
  private final NodeList nodeList;
  private int index = 0;

  public IterableNodeList(NodeList nodeList) {
    this.nodeList = nodeList;
  }

  @Override
  public Iterator<Node> iterator() {
    return this;
  }

  @Override
  public boolean hasNext() {
    return index < nodeList.getLength();
  }

  @Override
  public Node next() {
    return nodeList.item(index++);
  }

  @Override
  public void remove() {
    throw new UnsupportedOperationException();
  }
}
