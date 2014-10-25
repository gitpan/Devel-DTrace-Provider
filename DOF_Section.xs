#include "EXTERN.h"
#include "perl.h"
#include "XSUB.h"

#include "ppport.h"

#include <sys/dtrace.h>
#include <sys/utsname.h>

static uint8_t
fetch_attr_val(HV *hash, const char *name)
{
  SV **val;
  uint8_t attr_val;
  
  val = hv_fetch(hash, name, strlen(name), 0);
  if (val && *val && SvIOK(*val))
    attr_val = SvIV(*val);  
  else
    Perl_croak(aTHX_ "bad data for %s in fetch_attr_val", name);
  
  return attr_val;
}

static uint32_t
fetch_attrs(HV *hash, const char *name)
{
  SV **val;
  HV *attrs;
  uint32_t attr;
  uint8_t n, d, c;

  val = hv_fetch(hash, name, strlen(name), 0);
  if (val && *val && SvTYPE(SvRV(*val))) {
    if (SvTYPE(SvRV(*val)) == SVt_PVHV) {
      attrs = (HV *)SvRV(*val);
      n = fetch_attr_val(attrs, "name");
      d = fetch_attr_val(attrs, "data");
      c = fetch_attr_val(attrs, "class");
      attr = DOF_ATTR(n, d, c);
    }
    else
      Perl_croak(aTHX_ "bad data for %s in fetch_attrs", name);
  }
  else
    Perl_croak(aTHX_ "No '%s' in fetch_attrs", name);

  return attr;
}

MODULE = Devel::DTrace::DOF::Section		PACKAGE = Devel::DTrace::DOF::Section

PROTOTYPES: DISABLE

VERSIONCHECK: DISABLE  

SV *
header(self)
	SV *self

	INIT: 
	HV *data;
	SV **val;
	dof_sec_t hdr;

        CODE:
	if (SvROK(self) && SvTYPE(SvRV(self)) == SVt_PVHV) {
	  data = (HV *)SvRV(self);
	  memset(&hdr, 0, sizeof(hdr));

	  val = hv_fetch(data, "_flags", 6, 0);
	  if (val && *val)
	    hdr.dofs_flags = SvIV(*val);
	  else
	    Perl_croak(aTHX_ "No 'flags' in DOF::Section header");

	  val = hv_fetch(data, "_section_type", 13, 0);
	  if (val && *val)
	    hdr.dofs_type = SvIV(*val);
	  else
	    Perl_croak(aTHX_ "No 'section_type' in DOF::Section header");

	  val = hv_fetch(data, "_offset", 7, 0);
	  if (val && *val)
	    hdr.dofs_offset = SvIV(*val);
	  else
	    Perl_croak(aTHX_ "No 'offset' in DOF::Section header");
	  
	  val = hv_fetch(data, "_size", 5, 0);
	  if (val && *val)
	    hdr.dofs_size = SvIV(*val);
	  else
	    Perl_croak(aTHX_ "No 'size' in DOF::Section header");

	  val = hv_fetch(data, "_entsize", 8, 0);
	  if (val && *val)
	    hdr.dofs_entsize = SvIV(*val);
	  else
	    Perl_croak(aTHX_ "No 'entsize' in DOF::Section header");

	  val = hv_fetch(data, "_align", 6, 0);
	  if (val && *val)
	    hdr.dofs_align = SvIV(*val);
	  else
	    Perl_croak(aTHX_ "No 'align' in DOF::Section header");

	  RETVAL = newSVpvn((const char *)&hdr, sizeof(hdr));
	}
	else
	  Perl_croak(aTHX_ "self is not a hashref in DOF::Section header");

	OUTPUT:
	RETVAL

SV *
dof_generate_utsname(self)
	SV *self
	     
	INIT:
	struct utsname u;

        CODE:
	uname(&u);
	RETVAL = newSVpvn((const char *)&u, sizeof(struct utsname));
        OUTPUT:
	RETVAL

SV *
dof_generate_comments(self)
	SV *self
	
	INIT:
	HV *data;
	SV **val;

        CODE:
	if (SvROK(self) && SvTYPE(SvRV(self)) == SVt_PVHV) {
	  data = (HV *)SvRV(self);

	  val = hv_fetch(data, "_data", 5, 0);
	  if (val && *val && SvPOK(*val)) {
	    RETVAL = newSVsv(*val);
	    sv_catpvn(RETVAL, "", 1);
	  }
	  else
	    Perl_croak(aTHX_ "No 'data' in dof_generate_comments");
	}
        else
	    Perl_croak(aTHX_ "self is not a hashref in dof_generate_comments");

   	OUTPUT:
        RETVAL

SV *
dof_generate_probes(self)
	SV *self

	INIT:
	int i;
	HV *data;
	AV *probes;
	SV **probe;
	HV *probedata;
	SV *probedof;
	SV **val;
	dof_probe_t p;

        CODE:
	if (SvROK(self) && SvTYPE(SvRV(self)) == SVt_PVHV) {
	  data = (HV *)SvRV(self);
	  
	  val = hv_fetch(data, "_data", 5, 0);
	  if (val && *val && SvTYPE(SvRV(*val))) {
	    if (SvTYPE(SvRV(*val)) == SVt_PVAV) {
	      probes = (AV *)SvRV(*val);

	      RETVAL = newSVpvn("", 0);

	      for (i = 0; i <= av_len(probes); i++) {
		probe = av_fetch(probes, i, 0);
		if (probe && *probe && SvTYPE(SvRV(*probe)) == SVt_PVHV) {
		  probedata = (HV *)SvRV(*probe);
			   
		  memset(&p, 0, sizeof(p));
		
		  val = hv_fetch(probedata, "addr", 4, 0);
		  if (val && *val)
		    p.dofpr_addr = (uint64_t)SvIV(*val);
		  else
		    Perl_croak(aTHX_ "No 'addr' in DOF::Section probe");

		  val = hv_fetch(probedata, "func", 4, 0);
		  if (val && *val)
		    p.dofpr_func = (dof_stridx_t)SvIV(*val);
		  else
		    Perl_croak(aTHX_ "No 'func' in DOF::Section probe");

		  val = hv_fetch(probedata, "name", 4, 0);
		  if (val && *val)
		    p.dofpr_name = (dof_stridx_t)SvIV(*val);
		  else
		    Perl_croak(aTHX_ "No 'name' in DOF::Section probe");

		  val = hv_fetch(probedata, "nargv", 5, 0);
		  if (val && *val)
		    p.dofpr_nargv = (dof_stridx_t)SvIV(*val);
		  else
		    Perl_croak(aTHX_ "No 'nargv' in DOF::Section probe");

		  val = hv_fetch(probedata, "xargv", 5, 0);
		  if (val && *val)
		    p.dofpr_xargv = (dof_stridx_t)SvIV(*val);
		  else
		    Perl_croak(aTHX_ "No 'xargv' in DOF::Section probe");

		  val = hv_fetch(probedata, "argidx", 6, 0);
		  if (val && *val)
		    p.dofpr_argidx = (uint32_t)SvIV(*val);
		  else
		    Perl_croak(aTHX_ "No 'argidx' in DOF::Section probe");

		  val = hv_fetch(probedata, "offidx", 6, 0);
		  if (val && *val)
		    p.dofpr_offidx = (uint32_t)SvIV(*val);
		  else
		    Perl_croak(aTHX_ "No 'offidx' in DOF::Section probe");
    
		  val = hv_fetch(probedata, "nargc", 5, 0);
		  if (val && *val)
		    p.dofpr_nargc = (uint8_t)SvIV(*val);
		  else
		    Perl_croak(aTHX_ "No 'nargc' in DOF::Section probe");

		  val = hv_fetch(probedata, "xargc", 5, 0);
		  if (val && *val)
		    p.dofpr_xargc = (uint8_t)SvIV(*val);
		  else
		    Perl_croak(aTHX_ "No 'xargc' in DOF::Section probe");

		  val = hv_fetch(probedata, "noffs", 5, 0);
		  if (val && *val)
		    p.dofpr_noffs = (uint16_t)SvIV(*val);
		  else
		    Perl_croak(aTHX_ "No 'noffs' in DOF::Section probe");

		  val = hv_fetch(probedata, "enoffidx", 8, 0);
		  if (val && *val)
		    p.dofpr_enoffidx = (uint32_t)SvIV(*val);
		  else
		    Perl_croak(aTHX_ "No 'enoffidx' in DOF::Section probe");

		  val = hv_fetch(probedata, "nenoffs", 7, 0);
		  if (val && *val)
		    p.dofpr_nenoffs = (uint16_t)SvIV(*val);
		  else
		    Perl_croak(aTHX_ "No 'nenoffs' in DOF::Section probe");

		  probedof = newSVpvn((const char *)&p, sizeof(p));
		  sv_catsv(RETVAL, probedof);
		}
		else
		  Perl_croak(aTHX_ "probe data element is not a hashref in dof_generate_probes");
	      }
	    }
	    else 
	      Perl_croak(aTHX_ "bad data in dof_generate_probes");
	  }
	  else
	    Perl_croak(aTHX_ "No 'data' in dof_generate_probes");
	}
        else
	  Perl_croak(aTHX_ "self is not a hashref in dof_generate_probes");

        OUTPUT:
	RETVAL

SV *
dof_generate_prargs(self)
	SV *self

	INIT:
	HV *data;
	SV **val;
	AV *prargs;
	SV **prarg;
	uint8_t arg;
	int i;

        CODE:
	if (SvROK(self) && SvTYPE(SvRV(self)) == SVt_PVHV) {
	  data = (HV *)SvRV(self);
	  
	  val = hv_fetch(data, "_data", 5, 0);
	  if (val && *val && SvTYPE(SvRV(*val))) {
	    if (SvTYPE(SvRV(*val)) == SVt_PVAV) {
	      prargs = (AV *)SvRV(*val);
	      
	      RETVAL = newSVpvn("", 0);
	      
	      for (i = 0; i <= av_len(prargs); i++) {
		prarg = av_fetch(prargs, i, 0);
		if (prarg && SvIOK(*prarg)) {
		  arg = (uint8_t)SvIV(*prarg);
		  sv_catpvn(RETVAL, (char *)&arg, 1);
		}
		else
		  Perl_croak(aTHX_ "bad data for prarg");
	      }
	    }
	    else
	      Perl_croak(aTHX_ "bad data in DOF::Section prargs");
	  }
	  else 
	    Perl_croak(aTHX_ "No 'data' in DOF::Section prargs");
        }
	else
	  Perl_croak(aTHX_ "self is not a hashref in DOF::Section prargs");

	OUTPUT:
	RETVAL
	
SV *
dof_generate_proffs(self)
	SV *self

	INIT:
	HV *data;
	SV **val;
	AV *proffs;
	SV **proff;
	uint32_t off;
	int i;

        CODE:
	if (SvROK(self) && SvTYPE(SvRV(self)) == SVt_PVHV) {
	  data = (HV *)SvRV(self);
	  
	  val = hv_fetch(data, "_data", 5, 0);
	  if (val && *val && SvTYPE(SvRV(*val))) {
	    if (SvTYPE(SvRV(*val)) == SVt_PVAV) {
	      proffs = (AV *)SvRV(*val);
	      
	      RETVAL = newSVpvn("", 0);
	      
	      for (i = 0; i <= av_len(proffs); i++) {
		proff = av_fetch(proffs, i, 0);
		if (proff && SvIOK(*proff)) {
		  off = (uint32_t)SvIV(*proff);
		  sv_catpvn(RETVAL, (char *)&off, 4);
		}
		else
		  Perl_croak(aTHX_ "bad data for proff");
	      }
	    }
	    else
	      Perl_croak(aTHX_ "bad data in DOF::Section proffs");
	  }
	  else 
	    Perl_croak(aTHX_ "No 'data' in DOF::Section proffs");
        }
	else
	  Perl_croak(aTHX_ "self is not a hashref in DOF::Section proffs");

	OUTPUT:
	RETVAL

SV *
dof_generate_prenoffs(self)
	SV *self

	INIT:
	HV *data;
	SV **val;
	AV *prenoffs;
	SV **prenoff;
	uint32_t enoff;
	int i;

        CODE:
	if (SvROK(self) && SvTYPE(SvRV(self)) == SVt_PVHV) {
	  data = (HV *)SvRV(self);
	  
	  val = hv_fetch(data, "_data", 5, 0);
	  if (val && *val && SvTYPE(SvRV(*val))) {
	    if (SvTYPE(SvRV(*val)) == SVt_PVAV) {
	      prenoffs = (AV *)SvRV(*val);
	      
	      RETVAL = newSVpvn("", 0);
	      
	      for (i = 0; i <= av_len(prenoffs); i++) {
		prenoff = av_fetch(prenoffs, i, 0);
		if (prenoff && SvIOK(*prenoff)) {
		  enoff = (uint32_t)SvIV(*prenoff);
		  sv_catpvn(RETVAL, (char *)&enoff, 4);
		}
		else
		  Perl_croak(aTHX_ "bad data for prenoff");
	      }
	    }
	    else
	      Perl_croak(aTHX_ "bad data in DOF::Section prenoffs");
	  }
	  else 
	    Perl_croak(aTHX_ "No 'data' in DOF::Section prenoffs");
        }
	else
	  Perl_croak(aTHX_ "self is not a hashref in DOF::Section prenoffs");

	OUTPUT:
	RETVAL
	
SV *
dof_generate_provider(self)
	SV *self

	INIT: 
	HV *data;
	HV *provider;
	SV **val;
	dof_provider_t p;
	HV *attrs;
        dof_attr_t attr;
	uint8_t n, d, c;

        CODE:
	if (SvROK(self) && SvTYPE(SvRV(self)) == SVt_PVHV) {
	  data = (HV *)SvRV(self);
	  val = hv_fetch(data, "_data", 5, 0);

	  if (val && *val && SvTYPE(SvRV(*val))) {
	    if (SvTYPE(SvRV(*val)) == SVt_PVHV) {
	      provider = (HV *)SvRV(*val);
	      
	      memset(&p, 0, sizeof(p));
	      
	      val = hv_fetch(provider, "strtab", 6, 0);
	      if (val && *val)
		p.dofpv_strtab = (dof_secidx_t)SvIV(*val);
	      else
		Perl_croak(aTHX_ "No 'strtab' in DOF::Section provider");
	      
	      val = hv_fetch(provider, "probes", 6, 0);
	      if (val && *val)
		p.dofpv_probes = (dof_secidx_t)SvIV(*val);
	      else
		Perl_croak(aTHX_ "No 'probes' in DOF::Section provider");
	      
	      val = hv_fetch(provider, "prargs", 6, 0);
	      if (val && *val)
		p.dofpv_prargs = (dof_secidx_t)SvIV(*val);
	      else
		Perl_croak(aTHX_ "No 'prargs' in DOF::Section provider");
	      
	      val = hv_fetch(provider, "proffs", 6, 0);
	      if (val && *val)
		p.dofpv_proffs = (dof_secidx_t)SvIV(*val);
	      else
		Perl_croak(aTHX_ "No 'proffs' in DOF::Section provider");
	      
	      val = hv_fetch(provider, "name", 4, 0);
	      if (val && *val)
	      p.dofpv_name = (dof_stridx_t)SvIV(*val);
	      else
		Perl_croak(aTHX_ "No 'name' in DOF::Section provider");
	      
	      val = hv_fetch(provider, "prenoffs", 8, 0);
	      if (val && *val)
		p.dofpv_prenoffs = (dof_secidx_t)SvIV(*val);
	      else
		Perl_croak(aTHX_ "No 'prenoffs' in DOF::Section provider");
	      
	      p.dofpv_provattr = fetch_attrs(provider, "provattr");
	      p.dofpv_modattr  = fetch_attrs(provider, "modattr");
	      p.dofpv_funcattr = fetch_attrs(provider, "funcattr");
	      p.dofpv_nameattr = fetch_attrs(provider, "nameattr");
	      p.dofpv_argsattr = fetch_attrs(provider, "argsattr");
	      
	      RETVAL = newSVpvn((const char *)&p, sizeof(p));
	    }
	    else
	      Perl_croak(aTHX_ "bad data in DOF::Section provider");
	  }
	  else 
	    Perl_croak(aTHX_ "No 'data' in DOF::Section provider");
	}
	else
	  Perl_croak(aTHX_ "self is not a hashref in DOF::Section provider");

        OUTPUT:
	RETVAL

SV *
dof_generate_strtab(self)
	SV *self;
	
	INIT:
	int i;
	SV **val;
	AV *strings;
	SV **string;
	HV *data;

        CODE:
	if (SvROK(self) && SvTYPE(SvRV(self)) == SVt_PVHV) {
	  data = (HV *)SvRV(self);
	  
	  val = hv_fetch(data, "_data", 5, 0);
	  if (val && *val && SvTYPE(SvRV(*val))) {
	    if (SvTYPE(SvRV(*val)) == SVt_PVAV) {
	      strings = (AV *)SvRV(*val);
	      
	      RETVAL = newSVpvn("", 0);
	      sv_catpvn(RETVAL, "\0", 1);	    
	      
	      for (i = 0; i <= av_len(strings); i++) {
		string = av_fetch(strings, i, 0);
		if (string && SvPOK(*string)) {
		  sv_catsv(RETVAL, *string);
		  sv_catpvn(RETVAL, "", 1);
		}
		else 
		  Perl_croak(aTHX_ "bad string in strtab");
	      }
	    }
	    else
	      Perl_croak(aTHX_ "bad data in DOF::Section strtab");		
	  }
	  else
	    Perl_croak(aTHX_ "No 'data' in DOF::Section strtab");	    
	}
	else
	  Perl_croak(aTHX_ "self is not a hashref in DOF::Section strtab");

        OUTPUT:
        RETVAL
	  
