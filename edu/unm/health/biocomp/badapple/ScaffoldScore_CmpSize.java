package edu.unm.health.biocomp.badapple;

import java.io.*;
import java.util.*;

public class ScaffoldScore_CmpSize implements Comparator<ScaffoldScore>
{
  public int compare(ScaffoldScore s1,ScaffoldScore s2)
  {
    if (s1==null && s2==null) return 0;
    else if (s1==null && s2!=null) return -1;
    else if (s1!=null && s2==null) return 1;
    return (s1.getSmiles().length()<s2.getSmiles().length() ? 1 : (s1.getSmiles().length()>s2.getSmiles().length() ? -1 : 0));
  }
}
